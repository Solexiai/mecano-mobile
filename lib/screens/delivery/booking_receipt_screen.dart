import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../services/booking/booking_api.dart';
import '../../services/booking/booking_receipt_document.dart';
import '../../services/booking/booking_receipt_export_stub.dart'
    if (dart.library.js_interop) '../../services/booking/booking_receipt_export_web.dart'
    as receipt_export;
import '../../widgets/app_shell.dart';

class BookingReceiptScreen extends StatefulWidget {
  const BookingReceiptScreen({
    super.key,
    required this.missionId,
    required this.locale,
    this.api,
  });
  final String missionId, locale;
  final BookingApi? api;
  @override
  State<BookingReceiptScreen> createState() => _BookingReceiptScreenState();
}

class _BookingReceiptScreenState extends State<BookingReceiptScreen> {
  Future<Map<String, dynamic>>? _receipt;
  String? _uid;
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<FirebaseAuthProvider>().effectiveUid;
    if (uid != _uid) {
      _uid = uid;
      _receipt = uid == null
          ? null
          : (widget.api ?? FirebaseBookingApi(uid)).call('getBookingReceipt', {
              'missionId': widget.missionId,
            });
    }
  }

  @override
  void didUpdateWidget(covariant BookingReceiptScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.missionId != widget.missionId && _uid != null) {
      _receipt = (widget.api ?? FirebaseBookingApi(_uid)).call(
        'getBookingReceipt',
        {'missionId': widget.missionId},
      );
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
    locale: widget.locale,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  'Récapitulatif et conditions',
                  'Summary and terms',
                  'Resumen y condiciones',
                ),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              TextButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(
                      '/${widget.locale}/livraison/suivi/${widget.missionId}',
                    );
                  }
                },
                child: Text(
                  tr(
                    'Retour à la livraison',
                    'Back to delivery',
                    'Volver a la entrega',
                  ),
                ),
              ),
              if (_uid == null)
                Text(
                  tr(
                    'Connectez-vous au compte de cette réservation.',
                    'Sign in to the account that made this booking.',
                    'Inicia sesión en la cuenta de esta reserva.',
                  ),
                )
              else
                FutureBuilder<Map<String, dynamic>>(
                  key: ValueKey((_uid, widget.missionId)),
                  future: _receipt,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          Text(
                            tr(
                              'Récapitulatif indisponible ou inaccessible.',
                              'Summary unavailable or inaccessible.',
                              'Resumen no disponible o inaccesible.',
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _receipt =
                                  (widget.api ?? FirebaseBookingApi(_uid)).call(
                                    'getBookingReceipt',
                                    {'missionId': widget.missionId},
                                  );
                            }),
                            child: Text(tr('Réessayer', 'Retry', 'Reintentar')),
                          ),
                        ],
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final receipt = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.download_outlined),
                          label: Text(
                            kIsWeb
                                ? tr(
                                    'Télécharger le récapitulatif imprimable',
                                    'Download printable summary',
                                    'Descargar resumen imprimible',
                                  )
                                : tr(
                                    'Copier le récapitulatif',
                                    'Copy summary',
                                    'Copiar resumen',
                                  ),
                          ),
                          onPressed: () async {
                            if (!receipt_export.downloadBookingReceipt(
                              bookingReceiptHtml(receipt, widget.locale),
                              widget.missionId,
                            )) {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: bookingReceiptText(
                                    receipt,
                                    widget.locale,
                                  ),
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      tr(
                                        'Récapitulatif copié',
                                        'Summary copied',
                                        'Resumen copiado',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        if (kIsWeb)
                          Text(
                            tr(
                              'Ouvrez le fichier téléchargé puis utilisez Imprimer dans votre navigateur pour imprimer ou enregistrer en PDF.',
                              'Open the downloaded file and use Print in your browser to print or save as PDF.',
                              'Abre el archivo descargado y usa Imprimir en tu navegador para imprimir o guardar en PDF.',
                            ),
                          ),
                        const SizedBox(height: 20),
                        SelectableText(
                          bookingReceiptText(receipt, widget.locale),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
