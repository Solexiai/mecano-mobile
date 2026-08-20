// ---------------------------------------------------------------------------
// Tests unitaires — FinanceRepository (Bloc J)
//
// Couvre le contrat `NotConfiguredFinanceRepository` (utilisé tant qu'aucun
// projet Firebase réel n'est connecté — voir BackendLocator) pour les 3
// nouvelles méthodes Bloc J : elles ne doivent JAMAIS planter et retourner
// systématiquement un flux vide/null, jamais lever d'exception.
//
// NOTE : `FirebaseFinanceRepository` (implémentation réelle) nécessite une
// instance `FirebaseFirestore` initialisée (SDK natif, pas de fake
// disponible dans ce projet) — sa couverture "client scoped" se fait via
// les tests Security Rules ciblés côté backend (voir
// functions/test/integration/securityRules.test.ts, describes "Bloc J")
// qui vérifient que le SERVEUR ne renvoie que les documents autorisés,
// contrat sur lequel `FirebaseFinanceRepository` s'appuie sans aucun
// filtrage additionnel côté client (voir en-tête du fichier source).
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/repositories/finance_repository.dart';
import 'package:movik_connect/finance/models/payment_info.dart';
import 'package:movik_connect/finance/models/refund_info.dart';
import 'package:movik_connect/finance/models/mission_financial_balance.dart';

void main() {
  group('NotConfiguredFinanceRepository — Bloc J (aucun projet Firebase connecté)', () {
    const repo = NotConfiguredFinanceRepository();

    test('watchPaymentForMission ne plante jamais et retourne null', () async {
      final PaymentInfo? payment = await repo.watchPaymentForMission('mission_x').first;
      expect(payment, isNull);
    });

    test('watchRefundsForMission ne plante jamais et retourne une liste vide', () async {
      final List<RefundInfo> refunds = await repo.watchRefundsForMission('mission_x').first;
      expect(refunds, isEmpty);
    });

    test('watchMissionFinancialBalance ne plante jamais et retourne null', () async {
      final MissionFinancialBalance? balance =
          await repo.watchMissionFinancialBalance('mission_x').first;
      expect(balance, isNull);
    });
  });
}
