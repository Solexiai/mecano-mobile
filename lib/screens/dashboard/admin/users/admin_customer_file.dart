import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_colors.dart';
import '../../../../finance/presentation/money_format.dart';
import '../../../../l10n/app_strings.dart';

/// Appel d'une fonction serveur (remplaçable dans les tests).
typedef CustomerFileCall =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> data,
    );

/// Fiche client du service client (Daniel, 2026-11-10, phase 1) : tout ce
/// qu'un agent doit voir en 30 secondes — compte, chiffres clés, pastilles,
/// livraisons, prix non réservés, paiements, courriels, conditions acceptées,
/// notes internes et actions du personnel. Données servies par
/// `getAdminCustomerFile` ; un analyste voit une version masquée et ne peut
/// rien modifier.
class AdminCustomerFile extends StatefulWidget {
  const AdminCustomerFile({
    super.key,
    required this.userId,
    required this.locale,
    this.call,
  });
  final String userId;
  final String locale;
  final CustomerFileCall? call;

  @override
  State<AdminCustomerFile> createState() => _AdminCustomerFileState();
}

enum _Section { deliveries, payments, messages, notes }

class _AdminCustomerFileState extends State<AdminCustomerFile> {
  Future<Map<String, dynamic>>? _future;
  _Section _section = _Section.deliveries;
  final _note = TextEditingController();
  bool _busy = false;

  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (widget.call != null) return widget.call!(name, data);
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> _load() =>
      _call('getAdminCustomerFile', {'userId': widget.userId});

  void _reload() => setState(() => _future = _load());

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _money(num? minor) => formatMajorAmount(
    (minor ?? 0) / 100,
    locale: widget.locale,
    currencySymbol: r'$',
  );

  String _date(Object? iso, {bool time = true}) {
    final d = iso is String ? DateTime.tryParse(iso)?.toLocal() : null;
    if (d == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    final day = '${two(d.day)}/${two(d.month)}/${d.year}';
    return time ? '$day ${two(d.hour)}:${two(d.minute)}' : day;
  }

  String _missionStatus(String s) => switch (s) {
    'searching_driver' => tr('Recherche un chauffeur', 'Finding a driver', 'Buscando conductor'),
    'offered' => tr('Offerte aux chauffeurs', 'Offered to drivers', 'Ofrecida'),
    'assigned' => tr('Chauffeur confirmé', 'Driver confirmed', 'Conductor confirmado'),
    'driver_to_pickup' => tr('En route vers le ramassage', 'Heading to pickup', 'Hacia la recogida'),
    'arrived_at_pickup' => tr('Au ramassage', 'At pickup', 'En la recogida'),
    'picked_up' || 'in_transit' => tr('En route', 'In transit', 'En camino'),
    'arrived_at_dropoff' => tr('À la livraison', 'At drop-off', 'En la entrega'),
    'completed' => tr('Livrée', 'Delivered', 'Entregada'),
    'cancelled' => tr('Annulée', 'Cancelled', 'Cancelada'),
    'failed' => tr('Échouée', 'Failed', 'Fallida'),
    'payment_failed' => tr('Paiement refusé', 'Payment declined', 'Pago rechazado'),
    _ => s,
  };

  String _paymentKind(String k) => switch (k) {
    'deposit' => tr('Dépôt', 'Deposit', 'Depósito'),
    'tip' => tr('Pourboire', 'Tip', 'Propina'),
    'late_cancellation' => tr('Annulation tardive', 'Late cancellation', 'Cancelación tardía'),
    'failed_delivery' => tr('Déplacement pour rien', 'Wasted trip', 'Viaje en vano'),
    'fee' => tr('Frais', 'Fee', 'Cargo'),
    _ => tr('Livraison (solde)', 'Delivery (balance)', 'Entrega (saldo)'),
  };

  (String, Color) _paymentStatus(String s) => switch (s) {
    'captured' => (tr('Payé', 'Paid', 'Pagado'), AppColors.success),
    'partially_refunded' => (tr('Remboursé en partie', 'Partly refunded', 'Reembolso parcial'), AppColors.warning),
    'refunded' => (tr('Remboursé', 'Refunded', 'Reembolsado'), AppColors.textSecondary),
    'authorized' => (tr('Bloqué sur la carte', 'Held on card', 'Retenido'), AppColors.primary),
    'capture_failed' => (tr('Refusé', 'Declined', 'Rechazado'), AppColors.error),
    'capture_pending' || 'authorization_pending' => (tr('En cours', 'Pending', 'En curso'), AppColors.warning),
    'failed' => (tr('Échec', 'Failed', 'Fallido'), AppColors.error),
    'cancelled' || 'released' => (tr('Libéré', 'Released', 'Liberado'), AppColors.textSecondary),
    _ => (s, AppColors.textSecondary),
  };

  String _emailKind(String k) => switch (k) {
    'booking_confirmed' => tr('Réservation confirmée', 'Booking confirmed', 'Reserva confirmada'),
    'booking_confirmed_resend' => tr('Réservation confirmée (renvoi)', 'Booking confirmed (resent)', 'Reserva confirmada (reenvío)'),
    'pickup_reminder_customer' => tr('Rappel 4 h avant', '4-hour reminder', 'Recordatorio 4 h'),
    'payment_receipt_resend' => tr('Reçu (renvoi)', 'Receipt (resent)', 'Recibo (reenvío)'),
    _ => k,
  };

  (String, Color) _emailStatus(String s) => switch (s) {
    'sent' => (tr('Envoyé', 'Sent', 'Enviado'), AppColors.success),
    'not_configured' => (tr('Non envoyé : service de courriel pas configuré', 'Not sent: email service not set up', 'No enviado: servicio no configurado'), AppColors.warning),
    'no_address' => (tr('Aucune adresse courriel', 'No email address', 'Sin correo'), AppColors.warning),
    'failed' => (tr('Échec', 'Failed', 'Fallido'), AppColors.error),
    _ => (tr('En cours', 'Pending', 'En curso'), AppColors.textSecondary),
  };

  String _staffAction(String a) => switch (a) {
    'customer_note_added' => tr('Note ajoutée', 'Note added', 'Nota añadida'),
    'customer_note_pinned' => tr('Note épinglée', 'Note pinned', 'Nota fijada'),
    'customer_note_unpinned' => tr('Note désépinglée', 'Note unpinned', 'Nota desfijada'),
    'customer_email_resent' => tr('Courriel renvoyé', 'Email resent', 'Correo reenviado'),
    _ => a,
  };

  Future<void> _act(
    Future<Map<String, dynamic>> Function() action,
    String done,
  ) async {
    setState(() => _busy = true);
    String message;
    var error = false;
    try {
      final result = await action();
      message = switch (result['outcome']) {
        'not_configured' => tr(
          'Non envoyé : le service de courriel (Resend) n’est pas encore configuré.',
          'Not sent: the email service (Resend) is not set up yet.',
          'No enviado: el servicio de correo (Resend) aún no está configurado.',
        ),
        'no_address' => tr(
          'Non envoyé : ce client n’a pas d’adresse courriel.',
          'Not sent: this customer has no email address.',
          'No enviado: este cliente no tiene correo.',
        ),
        _ => done,
      };
      error = result['outcome'] == 'not_configured' || result['outcome'] == 'no_address';
    } on FirebaseFunctionsException catch (e) {
      message = e.message ?? tr('Action impossible.', 'Action failed.', 'Acción imposible.');
      error = true;
    } catch (_) {
      message = tr('Action impossible.', 'Action failed.', 'Acción imposible.');
      error = true;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
    _reload();
  }

  Widget _pill(String text, Color color, {Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
    ),
  );

  Widget _info(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label : ',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _stat(String label, String value, {Key? key}) => Container(
    key: key,
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F6FB),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _header(Map<String, dynamic> data) {
    final account = Map<String, dynamic>.from(data['account'] as Map? ?? {});
    final badges = (data['badges'] as List? ?? []).whereType<String>();
    return Card(
      key: const ValueKey('customer-file-header'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Fiche client', 'Customer file', 'Ficha del cliente'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: tr('Actualiser', 'Refresh', 'Actualizar'),
                  onPressed: _busy ? null : _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (badges.isNotEmpty || data['masked'] == true || account['disabled'] == true) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in badges)
                    switch (b) {
                      'new' => _pill(tr('Nouveau', 'New', 'Nuevo'), AppColors.primary, key: const ValueKey('badge-new')),
                      'loyal' => _pill(tr('Fidèle', 'Loyal', 'Fiel'), AppColors.success, key: const ValueKey('badge-loyal')),
                      'watch' => _pill(tr('À surveiller', 'Watch', 'Vigilar'), AppColors.error, key: const ValueKey('badge-watch')),
                      _ => _pill(b, AppColors.textSecondary),
                    },
                  if (account['disabled'] == true)
                    _pill(tr('Compte suspendu', 'Account suspended', 'Cuenta suspendida'), AppColors.error),
                  if (data['masked'] == true)
                    _pill(tr('Vue analyste (masquée)', 'Analyst view (masked)', 'Vista analista'), AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _info(Icons.event_outlined, tr('Inscrit le', 'Joined', 'Registrado'), _date(account['createdAt'], time: false)),
            _info(Icons.login, tr('Dernière connexion', 'Last sign-in', 'Último acceso'), _date(account['lastSignInAt'])),
            _info(
              Icons.mark_email_read_outlined,
              tr('Courriel', 'Email', 'Correo'),
              '${account['email'] ?? '—'} · ${account['emailVerified'] == true ? tr('vérifié ✓', 'verified ✓', 'verificado ✓') : tr('non vérifié', 'not verified', 'no verificado')}',
            ),
            _info(Icons.phone_outlined, tr('Téléphone', 'Phone', 'Teléfono'), '${account['phone'] ?? '—'}'),
            _info(Icons.translate, tr('Langue', 'Language', 'Idioma'), switch (account['locale']) {
              'en' => 'English',
              'es' => 'Español',
              'fr' => 'Français',
              _ => '—',
            }),
            _info(
              Icons.credit_card,
              tr('Carte au dossier', 'Card on file', 'Tarjeta guardada'),
              account['cardOnFile'] == true ? tr('Oui', 'Yes', 'Sí') : tr('Non', 'No', 'No'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(Map<String, dynamic> data) {
    final s = Map<String, dynamic>.from(data['stats'] as Map? ?? {});
    final avg = s['averageRatingGiven'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _stat(tr('Livraisons', 'Deliveries', 'Entregas'), '${s['deliveries'] ?? 0}', key: const ValueKey('stat-deliveries')),
          _stat(tr('Livrées', 'Delivered', 'Entregadas'), '${s['completed'] ?? 0}'),
          _stat(tr('Annulées', 'Cancelled', 'Canceladas'), '${s['cancelled'] ?? 0}'),
          _stat(tr('Total payé', 'Total paid', 'Total pagado'), _money(s['spentMinor'] as num?), key: const ValueKey('stat-spent')),
          _stat(tr('Pourboires', 'Tips', 'Propinas'), _money(s['tipsMinor'] as num?)),
          _stat(tr('Remboursé', 'Refunded', 'Reembolsado'), _money(s['refundedMinor'] as num?)),
          _stat(tr('Note donnée', 'Rating given', 'Nota dada'), avg is num ? '${avg.toString().replaceAll('.', ',')} ★' : '—'),
          _stat(tr('Prix non réservés', 'Quotes not booked', 'Precios sin reservar'), '${s['quotesNotBooked'] ?? 0}'),
        ],
      ),
    );
  }

  Widget _tabs(Map<String, dynamic> data) {
    int count(String key) => (data[key] as List? ?? const []).length;
    Widget chip(_Section section, String label) => ChoiceChip(
      key: ValueKey('customer-file-tab-${section.name}'),
      label: Text(label),
      selected: _section == section,
      onSelected: (_) => setState(() => _section = section),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(_Section.deliveries, '${tr('Livraisons', 'Deliveries', 'Entregas')} (${count('missions')})'),
        chip(_Section.payments, '${tr('Paiements', 'Payments', 'Pagos')} (${count('payments')})'),
        chip(_Section.messages, tr('Communications', 'Communications', 'Comunicaciones')),
        chip(_Section.notes, '${tr('Notes', 'Notes', 'Notas')} (${count('notes')})'),
      ],
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
  );

  Widget _subTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
  );

  List<Widget> _deliveries(Map<String, dynamic> data) {
    final canAct = data['canAct'] == true;
    final missions = (data['missions'] as List? ?? []).whereType<Map>();
    final quotes = (data['quotes'] as List? ?? []).whereType<Map>();
    return [
      if (missions.isEmpty) _empty(tr('Aucune livraison.', 'No deliveries.', 'Sin entregas.')),
      for (final m in missions)
        Card(
          key: ValueKey('customer-mission-${m['id']}'),
          child: ExpansionTile(
            title: Text(
              '${m['pickup'] ?? ''} → ${m['dropoff'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_date(m['pickupAt'] ?? m['createdAt'])} · ${_missionStatus('${m['status']}')} · ${_money(m['totalMinor'] as num?)}'
              '${m['internalTest'] == true ? ' · TEST' : ''}',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _info(Icons.inventory_2_outlined, tr('Objets', 'Items', 'Objetos'), '${m['items'] ?? '—'}'),
              _info(Icons.local_shipping_outlined, tr('Chauffeur', 'Driver', 'Conductor'), '${m['driverName'] ?? '—'}'),
              _info(Icons.schedule, tr('Réservée le', 'Booked', 'Reservada'), _date(m['createdAt'])),
              if (m['completedAt'] != null)
                _info(Icons.check_circle_outline, tr('Livrée le', 'Delivered', 'Entregada'), _date(m['completedAt'])),
              if (m['cancelledAt'] != null)
                _info(Icons.cancel_outlined, tr('Annulée le', 'Cancelled', 'Cancelada'), '${_date(m['cancelledAt'])} ${m['cancellationReason'] ?? ''}'),
              _info(Icons.savings_outlined, tr('Dépôt', 'Deposit', 'Depósito'), '${m['depositStatus'] ?? '—'}'),
              if ((m['tipMinor'] as num? ?? 0) > 0)
                _info(Icons.volunteer_activism, tr('Pourboire', 'Tip', 'Propina'), _money(m['tipMinor'] as num?)),
              _info(Icons.tag, tr('Référence', 'Reference', 'Referencia'), '${m['id']}'),
              if (canAct && m['internalTest'] != true)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: ValueKey('resend-confirmation-${m['id']}'),
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => _call('resendCustomerEmail', {
                              'userId': widget.userId,
                              'kind': 'booking_confirmed',
                              'missionId': m['id'],
                            }),
                            tr('Confirmation renvoyée.', 'Confirmation resent.', 'Confirmación reenviada.'),
                          ),
                    icon: const Icon(Icons.forward_to_inbox, size: 18),
                    label: Text(tr('Renvoyer la confirmation', 'Resend confirmation', 'Reenviar confirmación')),
                  ),
                ),
            ],
          ),
        ),
      if (quotes.isNotEmpty) ...[
        _subTitle(tr('Prix calculés sans réservation', 'Quotes not booked', 'Precios sin reservar')),
        for (final q in quotes)
          ListTile(
            key: ValueKey('customer-quote-${q['id']}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.request_quote_outlined),
            title: Text('${q['pickup'] ?? ''} → ${q['dropoff'] ?? ''}'),
            subtitle: Text(_date(q['createdAt'])),
            trailing: Text(_money(q['totalMinor'] as num?), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    ];
  }

  List<Widget> _payments(Map<String, dynamic> data) {
    final canAct = data['canAct'] == true;
    final payments = (data['payments'] as List? ?? []).whereType<Map>();
    return [
      if (payments.isEmpty) _empty(tr('Aucun paiement.', 'No payments.', 'Sin pagos.')),
      for (final p in payments)
        Card(
          key: ValueKey('customer-payment-${p['id']}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(_paymentKind('${p['kind']}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    _pill(_paymentStatus('${p['status']}').$1, _paymentStatus('${p['status']}').$2),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if ((p['capturedMinor'] as num? ?? 0) > 0) '${tr('Payé', 'Paid', 'Pagado')} ${_money(p['capturedMinor'] as num?)}',
                    if ((p['capturedMinor'] as num? ?? 0) == 0 && (p['authorizedMinor'] as num? ?? 0) > 0)
                      '${tr('Montant', 'Amount', 'Monto')} ${_money(p['authorizedMinor'] as num?)}',
                    if ((p['refundedMinor'] as num? ?? 0) > 0) '${tr('remboursé', 'refunded', 'reembolsado')} ${_money(p['refundedMinor'] as num?)}',
                    _date(p['capturedAt'] ?? p['createdAt']),
                    if (p['environment'] == 'test') 'TEST',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (canAct && p['hasReceipt'] == true)
                      TextButton.icon(
                        key: ValueKey('resend-receipt-${p['id']}'),
                        onPressed: _busy
                            ? null
                            : () => _act(
                                () => _call('resendCustomerEmail', {
                                  'userId': widget.userId,
                                  'kind': 'payment_receipt',
                                  'paymentId': p['id'],
                                }),
                                tr('Reçu renvoyé au client.', 'Receipt resent.', 'Recibo reenviado.'),
                              ),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: Text(tr('Renvoyer le reçu', 'Resend receipt', 'Reenviar recibo')),
                      ),
                    if (p['stripeUrl'] is String)
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse(p['stripeUrl'] as String), webOnlyWindowName: '_blank'),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(tr('Ouvrir dans Stripe', 'Open in Stripe', 'Abrir en Stripe')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _messages(Map<String, dynamic> data) {
    final emails = (data['emails'] as List? ?? []).whereType<Map>();
    final notifications = (data['notifications'] as List? ?? []).whereType<Map>();
    final consents = (data['consents'] as List? ?? []).whereType<Map>();
    return [
      _subTitle(tr('Courriels Movi-K', 'Movi-K emails', 'Correos de Movi-K')),
      if (emails.isEmpty) _empty(tr('Aucun courriel Movi-K envoyé.', 'No Movi-K email sent.', 'Ningún correo enviado.')),
      for (final e in emails)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mail_outline),
          title: Text(_emailKind('${e['kind']}')),
          subtitle: Text(_date(e['sentAt'] ?? e['createdAt'])),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              _emailStatus('${e['status']}').$1,
              textAlign: TextAlign.end,
              style: TextStyle(color: _emailStatus('${e['status']}').$2, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ),
      Text(
        tr(
          'Les reçus Stripe (dépôt, solde, pourboire) partent aussi automatiquement à chaque paiement.',
          'Stripe receipts (deposit, balance, tip) are also sent automatically for each payment.',
          'Los recibos de Stripe también se envían automáticamente con cada pago.',
        ),
        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      ),
      _subTitle(tr('Notifications dans l’app', 'In-app notifications', 'Notificaciones')),
      if (notifications.isEmpty) _empty(tr('Aucune notification.', 'No notifications.', 'Sin notificaciones.')),
      for (final n in notifications)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(n['read'] == true ? Icons.notifications_none : Icons.notifications_active_outlined),
          title: Text(
            n['titleKey'] is String ? AppStrings.t(n['titleKey'] as String, widget.locale) : '${n['type']}',
          ),
          subtitle: Text(_date(n['createdAt'])),
        ),
      _subTitle(tr('Conditions acceptées', 'Accepted terms', 'Condiciones aceptadas')),
      if (consents.isEmpty) _empty(tr('Aucune acceptation enregistrée.', 'No acceptance recorded.', 'Sin aceptación.')),
      for (final c in consents)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel_outlined),
          title: Text('${tr('Version', 'Version', 'Versión')} ${c['termsVersion'] ?? '—'} · ${_date(c['acceptedAt'])}'),
          subtitle: Text(
            '${tr('Offres promotionnelles', 'Promotional offers', 'Ofertas')} : ${c['marketing'] == true ? tr('oui', 'yes', 'sí') : tr('non', 'no', 'no')} · ${c['missionId']}',
          ),
        ),
    ];
  }

  List<Widget> _notes(Map<String, dynamic> data) {
    final canAct = data['canAct'] == true;
    final notes = (data['notes'] as List? ?? []).whereType<Map>();
    final actions = (data['staffActions'] as List? ?? []).whereType<Map>();
    return [
      if (canAct) ...[
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('customer-note-input'),
          controller: _note,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: tr('Note interne (jamais vue par le client)', 'Internal note (never seen by the customer)', 'Nota interna'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            key: const ValueKey('customer-note-add'),
            onPressed: _busy
                ? null
                : () {
                    final text = _note.text.trim();
                    if (text.isEmpty) return;
                    _act(() async {
                      final result = await _call('addCustomerNote', {'userId': widget.userId, 'text': text});
                      _note.clear();
                      return result;
                    }, tr('Note ajoutée.', 'Note added.', 'Nota añadida.'));
                  },
            icon: const Icon(Icons.note_add_outlined),
            label: Text(tr('Ajouter la note', 'Add note', 'Añadir nota')),
          ),
        ),
      ],
      if (notes.isEmpty) _empty(tr('Aucune note.', 'No notes.', 'Sin notas.')),
      for (final n in notes)
        Card(
          key: ValueKey('customer-note-${n['id']}'),
          color: n['pinned'] == true ? const Color(0xFFFFF6E5) : null,
          child: ListTile(
            leading: Icon(n['pinned'] == true ? Icons.push_pin : Icons.sticky_note_2_outlined),
            title: Text('${n['text']}'),
            subtitle: Text('${n['authorName'] ?? '—'} · ${_date(n['createdAt'])}'),
            trailing: canAct
                ? IconButton(
                    key: ValueKey('customer-note-pin-${n['id']}'),
                    tooltip: n['pinned'] == true ? tr('Désépingler', 'Unpin', 'Desfijar') : tr('Épingler', 'Pin', 'Fijar'),
                    icon: Icon(n['pinned'] == true ? Icons.push_pin_outlined : Icons.push_pin),
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => _call('setCustomerNotePinned', {'noteId': n['id'], 'pinned': n['pinned'] != true}),
                            tr('Note mise à jour.', 'Note updated.', 'Nota actualizada.'),
                          ),
                  )
                : null,
          ),
        ),
      _subTitle(tr('Actions du personnel sur ce compte', 'Staff actions on this account', 'Acciones del personal')),
      if (actions.isEmpty) _empty(tr('Aucune action.', 'No actions.', 'Sin acciones.')),
      for (final a in actions)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: Text(_staffAction('${a['action']}')),
          subtitle: Text('${_date(a['createdAt'])} · ${a['actorUserId'] ?? '—'}'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Card(
          key: const ValueKey('customer-file-error'),
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: AppColors.error),
            title: Text(tr('Fiche client indisponible', 'Customer file unavailable', 'Ficha no disponible')),
            trailing: TextButton(onPressed: _reload, child: Text(tr('Réessayer', 'Retry', 'Reintentar'))),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final data = snapshot.data!;
      return Column(
        key: const ValueKey('customer-file'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(data),
          _stats(data),
          _tabs(data),
          const SizedBox(height: 8),
          ...switch (_section) {
            _Section.deliveries => _deliveries(data),
            _Section.payments => _payments(data),
            _Section.messages => _messages(data),
            _Section.notes => _notes(data),
          },
        ],
      );
    },
  );
}
