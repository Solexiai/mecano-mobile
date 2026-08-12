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

  FirebaseAuthProvider({required bool backendConfigured})
    : _backendConfigured = backendConfigured {
    if (_backendConfigured) {
      _authSub = fb.FirebaseAuth.instance.authStateChanges().listen(
        _onAuthChanged,
      );
    }
  }

  fb.User? get user => _user;
  bool get isSignedIn => _user != null;
  List<PlatformRole> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// true une fois que les custom claims ont été chargés au moins une fois
  /// pour l'utilisateur courant (évite un flash "accès refusé" pendant le
  /// court instant où les claims sont encore en cours de lecture après
  /// authStateChanges()).
  bool get claimsLoaded => _claimsLoaded;

  bool hasRole(PlatformRole role) => _roles.contains(role);
  bool get isAdminOrAbove =>
      hasRole(PlatformRole.admin) || hasRole(PlatformRole.superAdmin);
  bool get isSuperAdmin => hasRole(PlatformRole.superAdmin);

  Future<void> _onAuthChanged(fb.User? user) async {
    _user = user;
    _claimsLoaded = false;
    if (user == null) {
      _roles = [];
      _claimsLoaded = true;
    } else {
      await _refreshClaims(force: true);
    }
    notifyListeners();
  }

  Future<void> _refreshClaims({bool force = false}) async {
    if (_user == null) return;
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
    } catch (_) {
      _roles = [];
    } finally {
      _claimsLoaded = true;
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
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
