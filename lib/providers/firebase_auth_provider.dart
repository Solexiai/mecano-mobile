// ---------------------------------------------------------------------------
// FirebaseAuthProvider — état d'authentification RÉEL basé sur Firebase Auth.
//
// SÉCURITÉ :
// - Les rôles exposés ici (`roles`, `isAdminOrAbove`, `isSuperAdmin`) sont
//   lus EXCLUSIVEMENT depuis les Firebase Auth Custom Claims (via
//   `getIdTokenResult()`), jamais depuis un champ Firestore ou un état
//   local. Un claim ne peut être modifié que côté serveur (Cloud Function
//   `setUserRole`, ou le script one-shot de bootstrap initial).
// - Ce provider ne sert QUE de source de vérité pour l'AFFICHAGE côté
//   client (show/hide UI). Toute action sensible reste re-validée
//   serverside par les Firestore Security Rules et/ou les Cloud Functions.
// - Ne fonctionne que si le backend Firebase est réellement configuré
//   (voir BackendBootstrap) : sinon, reste inerte et retourne des erreurs
//   explicites plutôt que de planter l'application.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../models/enums.dart';

class FirebaseAuthProvider extends ChangeNotifier {
  final bool _backendConfigured;
  StreamSubscription<fb.User?>? _authSub;

  fb.User? _user;
  List<PlatformRole> _roles = [];
  bool _isLoading = false;
  String? _lastError;
  bool _claimsLoaded = false;
  bool _claimsFetchFailed = false;

  FirebaseAuthProvider({required bool backendConfigured})
    : _backendConfigured = backendConfigured {
    if (_backendConfigured) {
      _authSub = fb.FirebaseAuth.instance.authStateChanges().listen(
        _onAuthChanged,
      );
    }
  }

  // ---------------------------------------------------------------------
  // Seam de test (Phase 7, Bloc B, MIS-C-09) — `fb.User` est une classe
  // opaque du SDK Firebase Auth qu'on ne peut pas construire manuellement
  // sans initialiser un vrai projet Firebase (ou un package de mocks non
  // installé dans ce projet). Ce flag permet aux widget tests de simuler
  // un état "connecté" pour tester le contenu protégé d'un écran (ex:
  // `DeliveryRequestFlowScreen`) SANS dépendre de Firebase réel. `@visibleForTesting`
  // documente l'intention : ne JAMAIS positionner ce champ en dehors de
  // `test/`. `user` reste `null` dans ce mode (seul `isSignedIn` est
  // affecté) — les écrans qui lisent `auth.user!.uid` doivent donc être
  // testés séparément ou tolérer `null` dans ce mode spécifique.
  // ---------------------------------------------------------------------
  @visibleForTesting
  bool debugForceSignedIn = false;
  @visibleForTesting
  String? debugForceUid;
  @visibleForTesting
  String? debugForceDisplayName;
  @visibleForTesting
  String? debugForceEmail;

  /// Seam de test (Phase 7, Bloc E) — permet à un widget test de simuler un
  /// jeu de rôles/claims effectifs (ex: `[PlatformRole.admin]`) SANS
  /// dépendre d'un vrai token Firebase Auth. `null` = comportement normal
  /// (utiliser les claims réellement chargés dans `_roles`). Ne JAMAIS
  /// positionner ce champ en dehors de `test/` — comme les autres seams
  /// `debugForce*`, il n'a aucun effet sur l'autorisation SERVEUR (Cloud
  /// Functions / Security Rules), qui reste la seule autorité réelle ; il
  /// ne pilote que l'affichage côté client dans les tests.
  @visibleForTesting
  List<PlatformRole>? debugForceRoles;

  /// Seams de test (Phase 7, Bloc E) — permettent de simuler précisément les
  /// états `claimsLoaded`/`claimsFetchFailed` consommés par `AdminAuthGate`
  /// (écran de chargement, écran "réessayer" en cas d'échec réseau des
  /// claims) sans dépendre d'un vrai cycle Firebase Auth. `null` =
  /// comportement normal (valeur réelle `_claimsLoaded`/`_claimsFetchFailed`).
  @visibleForTesting
  bool? debugForceClaimsLoaded;
  @visibleForTesting
  bool? debugForceClaimsFetchFailed;

  fb.User? get user => _user;
  bool get isSignedIn => _user != null || debugForceSignedIn;

  /// Identifiant client effectif : l'uid Firebase réel si connecté, sinon
  /// (uniquement en test, `debugForceSignedIn == true`) l'uid simulé. Les
  /// écrans qui ont besoin de l'identité du client courant doivent utiliser
  /// ce getter plutôt que `user!.uid` directement, pour rester testables
  /// sans dépendance à un vrai utilisateur Firebase.
  String? get effectiveUid => _user?.uid ?? debugForceUid;
  String? get effectiveDisplayName => _user?.displayName ?? debugForceDisplayName;
  String? get effectiveEmail => _user?.email ?? debugForceEmail;
  List<PlatformRole> get roles => debugForceRoles ?? _roles;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// true une fois que les custom claims ont été chargés au moins une fois
  /// pour l'utilisateur courant (évite un flash "accès refusé" pendant le
  /// court instant où les claims sont encore en cours de lecture après
  /// authStateChanges()).
  bool get claimsLoaded => debugForceClaimsLoaded ?? _claimsLoaded;

  /// true si la dernière tentative de lecture des custom claims a échoué
  /// (erreur réseau/interop transitoire), PAS si l'utilisateur n'a
  /// simplement aucun rôle. Permet à l'UI/AdminLoginScreen de proposer un
  /// nouvel essai plutôt que de déconnecter à tort un compte légitime.
  bool get claimsFetchFailed => debugForceClaimsFetchFailed ?? _claimsFetchFailed;

  bool hasRole(PlatformRole role) => roles.contains(role);
  bool get isAdminOrAbove =>
      hasRole(PlatformRole.admin) || hasRole(PlatformRole.superAdmin);
  bool get isSuperAdmin => hasRole(PlatformRole.superAdmin);

  /// Phase 2 — portail analyste : un analyste doit pouvoir accéder à
  /// `/admin/chauffeurs` (consulter/approuver/refuser des dossiers) sans
  /// pour autant avoir les droits admin/super_admin complets. Reflète
  /// exactement `PlatformRoleX.canReviewDrivers` côté serveur
  /// (functions/src/lib/auth.ts: requireAnalystOrAbove).
  bool get isAnalystOrAbove =>
      hasRole(PlatformRole.analyst) || isAdminOrAbove;

  Future<void> _onAuthChanged(fb.User? user) async {
    _user = user;
    _claimsLoaded = false;
    if (user == null) {
      _roles = [];
      _claimsFetchFailed = false;
      _claimsLoaded = true;
    } else {
      await _refreshClaims(force: true);
    }
    notifyListeners();
  }

  /// Lit les custom claims via getIdTokenResult(), avec retries courts pour
  /// absorber les erreurs transitoires (réseau, interop JS juste après un
  /// signIn/signOut sur Flutter Web). Ne met JAMAIS `_roles = []` sur simple
  /// échec réseau : dans ce cas `_claimsFetchFailed` est levé pour que
  /// l'appelant sache qu'il doit réessayer plutôt que conclure "pas de rôle".
  Future<void> _refreshClaims({bool force = false}) async {
    if (_user == null) return;
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final tokenResult = await _user!.getIdTokenResult(force);
        final claims = tokenResult.claims;
        final rawRoles = (claims?['roles'] as List?)
            ?.map((e) => e.toString())
            .toList();
        if (rawRoles != null && rawRoles.isNotEmpty) {
          _roles = rawRoles.map(PlatformRoleX.fromClaim).toList();
        } else if (claims?['role'] != null) {
          _roles = [PlatformRoleX.fromClaim(claims!['role'] as String)];
        } else {
          _roles = [];
        }
        _claimsFetchFailed = false;
        _claimsLoaded = true;
        return;
      } catch (_) {
        if (attempt == maxAttempts) {
          // Échec persistant après plusieurs tentatives : on ne vide PAS
          // les rôles déjà connus (le cas échéant), on signale juste
          // l'échec pour que l'UI puisse réagir sans déconnecter le compte.
          _claimsFetchFailed = true;
          _claimsLoaded = true;
          return;
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  /// À appeler après un `setUserRole` réussi côté serveur, pour que le
  /// client voie immédiatement le nouveau rôle sans se déconnecter.
  Future<void> refreshClaims() async {
    await _refreshClaims(force: true);
    notifyListeners();
  }

  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (!_backendConfigured) {
      _lastError = 'Backend Firebase non configuré sur cet environnement.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final cred = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = cred.user;
      _claimsLoaded = false;
      await _refreshClaims(force: true);
      _isLoading = false;
      notifyListeners();
      return true;
    } on fb.FirebaseAuthException catch (e) {
      _lastError = _mapErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _lastError = 'Une erreur inattendue est survenue. Réessayez.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Crée un nouveau compte Firebase Auth (email/password) et un document
  /// `users/{uid}` initial avec `roles: ['customer']` (seule valeur permise
  /// par la règle `create` de `users/{userId}` — voir firestore.rules).
  /// Toute élévation de rôle ultérieure (ex: `driver`) passe par une Cloud
  /// Function dédiée (`registerAsDriver`), jamais par une écriture directe.
  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (!_backendConfigured) {
      _lastError = 'Backend Firebase non configuré sur cet environnement.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(fullName.trim());

      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email.trim(),
        'full_name': fullName.trim(),
        'roles': ['customer'],
        'created_at': DateTime.now().toIso8601String(),
        'is_disabled': false,
        'email_verified': false,
      });

      _user = cred.user;
      _claimsLoaded = false;
      await _refreshClaims(force: true);
      _isLoading = false;
      notifyListeners();
      return true;
    } on fb.FirebaseAuthException catch (e) {
      _lastError = _mapErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _lastError = 'Une erreur inattendue est survenue. Réessayez.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _mapErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Adresse courriel ou mot de passe incorrect.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion.';
      case 'invalid-email':
        return 'Adresse courriel invalide.';
      default:
        return 'Connexion impossible ($code).';
    }
  }

  Future<void> signOut() async {
    if (!_backendConfigured) return;
    await fb.FirebaseAuth.instance.signOut();
    _user = null;
    _roles = [];
    _lastError = null;
    _claimsFetchFailed = false;
    // authStateChanges() va aussi émettre `null` et repasser par
    // _onAuthChanged, mais on met à jour l'état tout de suite ici pour un
    // retour visuel instantané ; _claimsLoaded reste `true` (aucun claim à
    // charger pour un utilisateur déconnecté).
    _claimsLoaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
