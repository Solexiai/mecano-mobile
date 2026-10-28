// ADM-01 (2026-10-28) : remboursement et statut de litige depuis l'admin.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/repositories/finance_repository.dart';
import 'package:movik_connect/finance/models/dispute_info.dart';
import 'package:movik_connect/finance/models/payment_info.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/widgets/dispute_status_menu.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/widgets/refund_payment_dialog.dart';

String _t(String key) => AppStrings.t(key, 'fr');

PaymentInfo _payment({int captured = 2500, int refunded = 0}) => PaymentInfo(
  paymentId: 'pay_1',
  missionId: 'mission_1',
  customerId: 'cust_1',
  driverId: 'drv_1',
  status: PaymentStatus.captured,
  currency: 'CAD',
  amountAuthorizedMinor: 3000,
  amountCapturedMinor: captured,
  amountRefundedMinor: refunded,
  applicationFeeMinor: 500,
  provider: 'stripe',
  createdAt: DateTime(2026, 10, 28),
  updatedAt: DateTime(2026, 10, 28),
);

class _Repo extends NotConfiguredFinanceRepository {
  final refunds = <Map<String, Object?>>[];
  final disputes = <Map<String, Object?>>[];
  @override
  Future<void> adminRefundPayment({
    required String paymentId,
    required RefundReason reason,
    int? amountMinor,
    String? clientRequestId,
  }) async {
    refunds.add({'paymentId': paymentId, 'reason': reason, 'amountMinor': amountMinor, 'clientRequestId': clientRequestId});
  }

  @override
  Future<void> adminUpdateDisputeStatus({required String disputeId, required DisputeStatus newStatus}) async {
    disputes.add({'disputeId': disputeId, 'newStatus': newStatus});
  }
}

Widget _host(Widget Function(BuildContext) builder) =>
    MaterialApp(home: Scaffold(body: Builder(builder: builder)));

void main() {
  group('helpers', () {
    test('montant remboursable et saisie en dollars', () {
      expect(refundableMinor(_payment()), 2500);
      expect(refundableMinor(_payment(captured: 2500, refunded: 2500)), 0);
      expect(refundableMinor(_payment(captured: 0)), 0);
      expect(parseAmountMinor('12,50'), 1250);
      expect(parseAmountMinor('12.5'), 1250);
      expect(parseAmountMinor(' 7 \$'), 700);
      expect(parseAmountMinor('0'), isNull);
      expect(parseAmountMinor('abc'), isNull);
    });

    test('transitions de litige = machine d’état serveur', () {
      expect(disputeTransitions[DisputeStatus.opened], [DisputeStatus.underReview, DisputeStatus.won, DisputeStatus.lost]);
      expect(disputeTransitions[DisputeStatus.lost], [DisputeStatus.reversed, DisputeStatus.closed]);
      expect(disputeTransitions[DisputeStatus.closed], isEmpty);
      for (final s in DisputeStatus.values) {
        expect(disputeTransitions.containsKey(s), isTrue, reason: s.name);
      }
    });
  });

  testWidgets('remboursement total puis partiel : la fonction reçoit motif, montant et clé de rejeu', (t) async {
    final repo = _Repo();
    late BuildContext ctx;
    await t.pumpWidget(_host((c) {
      ctx = c;
      return const SizedBox();
    }));

    // Total.
    final full = showRefundPaymentDialog(ctx, payment: _payment(), t: _t, repository: repo);
    await t.pumpAndSettle();
    expect(find.textContaining('25.00'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('refund-confirm')));
    await t.pumpAndSettle();
    expect(await full, isTrue);
    expect(repo.refunds.single['amountMinor'], isNull);
    expect(repo.refunds.single['reason'], RefundReason.customerRequest);
    expect(repo.refunds.single['clientRequestId'], startsWith('admin_pay_1_'));

    // Partiel : montant trop élevé refusé, puis 10 $ accepté.
    final partial = showRefundPaymentDialog(ctx, payment: _payment(), t: _t, repository: repo);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('refund-partial')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('refund-amount')), '30');
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('refund-confirm'))).onPressed, isNull);
    expect(find.text(_t('admin_refund_amount_too_high')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('refund-amount')), '10');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('refund-confirm')));
    await t.pumpAndSettle();
    expect(await partial, isTrue);
    expect(repo.refunds.last['amountMinor'], 1000);
  });

  testWidgets('litige : seules les transitions permises sont proposées, confirmation, appel serveur', (t) async {
    final repo = _Repo();
    final dispute = DisputeInfo(
      disputeId: 'dp_1',
      missionId: 'mission_1',
      paymentId: 'pay_1',
      providerDisputeId: 'du_1',
      amountMinor: 2500,
      currency: 'CAD',
      reason: 'fraudulent',
      status: DisputeStatus.lost,
      createdAt: DateTime(2026, 10, 28),
      updatedAt: DateTime(2026, 10, 28),
    );
    await t.pumpWidget(_host((_) => DisputeStatusMenu(dispute: dispute, t: _t, repository: repo)));
    await t.tap(find.byKey(const ValueKey('dispute-menu-dp_1')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('dispute-next-reversed')), findsOneWidget);
    expect(find.byKey(const ValueKey('dispute-next-closed')), findsOneWidget);
    expect(find.byKey(const ValueKey('dispute-next-won')), findsNothing);
    await t.tap(find.byKey(const ValueKey('dispute-next-closed')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('dispute-confirm')));
    await t.pumpAndSettle();
    expect(repo.disputes.single, {'disputeId': 'dp_1', 'newStatus': DisputeStatus.closed});

    // Un litige fermé n'a plus d'action.
    await t.pumpWidget(_host((_) => DisputeStatusMenu(
      dispute: DisputeInfo(
        disputeId: 'dp_2', missionId: 'm', paymentId: 'p', providerDisputeId: 'du', amountMinor: 1, currency: 'CAD',
        reason: '', status: DisputeStatus.closed, createdAt: DateTime(2026), updatedAt: DateTime(2026),
      ),
      t: _t,
      repository: repo,
    )));
    expect(find.byKey(const ValueKey('dispute-menu-dp_2')), findsNothing);
  });
}
