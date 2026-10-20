import 'driver_dialog.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/booking/booking_api.dart';
import '../services/calendar_export.dart';

class DriverCalendarsPanel extends StatefulWidget {
  const DriverCalendarsPanel({
    super.key,
    required this.api,
    required this.locale,
  });
  final BookingApi api;
  final String locale;
  @override
  State<DriverCalendarsPanel> createState() => _DriverCalendarsPanelState();
}

class _DriverCalendarsPanelState extends State<DriverCalendarsPanel> {
  Map<String, dynamic>? _data;
  bool _busy = false;
  String? _message;
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DriverCalendarsPanel old) {
    super.didUpdateWidget(old);
    if (old.api != widget.api) {
      _data = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.call('getDriverCalendars');
      if (mounted) setState(() => _data = d);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = tr(
            'Impossible de charger les connexions.',
            'Unable to load connections.',
            'No se pudieron cargar las conexiones.',
          ),
        );
      }
    }
  }

  Future<void> run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await task();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = tr(
            'L’opération n’a pas abouti. Réessayez ou reconnectez le calendrier.',
            'The operation failed. Retry or reconnect the calendar.',
            'La operación falló. Reintenta o conecta el calendario otra vez.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> connect(String provider) async {
    bool consent = false, write = false;
    final ok = await showDriverDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            tr(
              'Connecter mon calendrier',
              'Connect my calendar',
              'Conectar mi calendario',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(
                    'Movi-K utilisera les périodes occupées pour éviter les conflits. Les titres et participants de vos rendez-vous ne seront pas conservés.',
                    'Movi-K will use busy periods to avoid conflicts. Appointment titles and attendees will not be stored.',
                    'Movi-K utilizará los períodos ocupados para evitar conflictos. No se guardarán los títulos ni los participantes.',
                  ),
                ),
                CheckboxListTile(
                  value: consent,
                  onChanged: (v) => set(() => consent = v == true),
                  title: Text(
                    tr(
                      'J’autorise la lecture de mes disponibilités.',
                      'I authorize access to my availability.',
                      'Autorizo el acceso a mi disponibilidad.',
                    ),
                  ),
                ),
                CheckboxListTile(
                  value: write,
                  onChanged: (v) => set(() => write = v == true),
                  title: Text(
                    tr(
                      'Ajouter aussi mes missions à un calendrier Movi-K distinct.',
                      'Also add my missions to a separate Movi-K calendar.',
                      'Añadir mis misiones a un calendario Movi-K separado.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Retour', 'Back', 'Volver')),
            ),
            FilledButton(
              onPressed: consent ? () => Navigator.pop(ctx, true) : null,
              child: Text(tr('Continuer', 'Continue', 'Continuar')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await run(() async {
      final response = await widget.api.call('startDriverCalendarConnection', {
        'provider': provider,
        'write_allowed': write,
        'consent': true,
      });
      final uri = Uri.parse(response['url'] as String);
      if (uri.scheme != 'https' ||
          ![
            'accounts.google.com',
            'login.microsoftonline.com',
          ].contains(uri.host)) {
        throw StateError('Invalid OAuth URL');
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unable to open authorization');
      }
      if (mounted) {
        setState(
          () => _message = tr(
            'Après autorisation, revenez ici et utilisez « Confirmer avec le code ».',
            'After authorization, return here and choose “Confirm with code”.',
            'Después de autorizar, vuelve aquí y elige «Confirmar con código».',
          ),
        );
      }
    });
  }

  Future<void> finish() async {
    final input = TextEditingController();
    final ok = await showDriverDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr(
            'Confirmer la connexion',
            'Confirm connection',
            'Confirmar conexión',
          ),
        ),
        content: TextField(
          controller: input,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: tr(
              'Code reçu après autorisation',
              'Code received after authorization',
              'Código recibido tras autorizar',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Retour', 'Back', 'Volver')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Confirmer', 'Confirm', 'Confirmar')),
          ),
        ],
      ),
    );
    final claim = input.text.trim();
    input.dispose();
    if (ok == true) {
      await run(() async {
        await widget.api.call('finishDriverCalendarConnection', {
          'claim': claim,
        });
      });
    }
  }

  Future<void> select(String provider) async => run(() async {
    final response = await widget.api.call('listDriverCalendars', {
      'provider': provider,
    });
    if (!mounted) return;
    final selected = <String>{}, list = response['calendars'] as List;
    final ok = await showDriverDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            tr(
              'Calendriers à prendre en compte',
              'Calendars to check',
              'Calendarios que consultar',
            ),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final calendar in list)
                    CheckboxListTile(
                      value: selected.contains(calendar['id']),
                      onChanged: (v) => set(() {
                        if (v == true) {
                          selected.add(calendar['id'] as String);
                        } else {
                          selected.remove(calendar['id']);
                        }
                      }),
                      title: Text(calendar['name'] as String? ?? provider),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Retour', 'Back', 'Volver')),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(tr('Enregistrer', 'Save', 'Guardar')),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await widget.api.call('selectDriverCalendars', {
        'provider': provider,
        'calendar_ids': selected.toList(),
      });
      await refresh();
    }
  });
  Future<void> refresh() async {
    final now = DateTime.now().toUtc();
    await widget.api.call('refreshDriverCalendars', {
      'start': now.toIso8601String(),
      'end': now.add(const Duration(days: 30)).toIso8601String(),
    });
    await widget.api.call('retryDriverCalendarSync');
  }

  Future<void> disconnect(String provider) async {
    final ok = await showDriverDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr(
            'Déconnecter le calendrier ?',
            'Disconnect calendar?',
            '¿Desconectar calendario?',
          ),
        ),
        content: Text(
          tr(
            'Ses rendez-vous ne bloqueront plus vos disponibilités. Les événements déjà copiés dans le calendrier externe y resteront.',
            'Its appointments will no longer block your availability. Events already copied to the external calendar will remain there.',
            'Sus citas dejarán de bloquear tu disponibilidad. Los eventos ya copiados al calendario externo permanecerán allí.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Conserver', 'Keep', 'Mantener')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Déconnecter', 'Disconnect', 'Desconectar')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await run(() async {
        final result = await widget.api.call('disconnectDriverCalendar', {
          'provider': provider,
        });
        if (result['manual_revocation_required'] == true && mounted) {
          setState(
            () => _message = tr(
              'Connexion supprimée de Movi-K. Retirez aussi l’autorisation dans les paramètres de sécurité de votre compte calendrier.',
              'Connection removed from Movi-K. Also revoke permission in your calendar account’s security settings.',
              'Conexión eliminada de Movi-K. Revoca también el permiso en la seguridad de tu cuenta de calendario.',
            ),
          );
        }
      });
    }
  }

  String state(String s) => switch (s) {
    'ready' => tr('Connecté', 'Connected', 'Conectado'),
    'synced' => tr(
      'À jour au dernier contrôle',
      'Up to date at last check',
      'Actualizado en la última comprobación',
    ),
    'pending' => tr(
      'Copie des missions en attente',
      'Mission sync pending',
      'Copia de misiones pendiente',
    ),
    'not_connected' => tr(
      'Copie automatique désactivée',
      'Automatic copying disabled',
      'Copia automática desactivada',
    ),
    'selection_required' => tr(
      'Calendriers à choisir',
      'Choose calendars',
      'Elige calendarios',
    ),
    'reconnect_required' => tr(
      'Reconnexion nécessaire',
      'Reconnect required',
      'Reconexión necesaria',
    ),
    'error' => tr(
      'Échec de synchronisation',
      'Sync failed',
      'Error de sincronización',
    ),
    _ => tr(
      'Actualisation nécessaire',
      'Refresh required',
      'Actualización necesaria',
    ),
  };
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(
      tr(
        'Mes calendriers connectés',
        'My connected calendars',
        'Mis calendarios conectados',
      ),
    ),
    childrenPadding: const EdgeInsets.all(12),
    children: [
      if (_busy || _data == null && _message == null)
        const LinearProgressIndicator(),
      if (_data?['available'] != true)
        Text(
          tr(
            'Les connexions Google et Outlook attendent la configuration et l’autorisation de Movi-K.',
            'Google and Outlook connections await Movi-K configuration and approval.',
            'Las conexiones de Google y Outlook requieren la configuración y autorización de Movi-K.',
          ),
        ),
      if (_data != null)
        Text(state(_data!['event_sync_status'] as String? ?? 'not_connected')),
      for (final p in ['google', 'microsoft']) ...[
        ListTile(
          title: Text(p == 'google' ? 'Google Calendar' : 'Microsoft Outlook'),
          subtitle: Text(
            (_data?['connections'] as List? ?? []).any(
                  (c) => c['provider'] == p,
                )
                ? state(
                    ((_data!['connections'] as List).firstWhere(
                          (c) => c['provider'] == p,
                        ))['state']
                        as String,
                  )
                : tr('Non connecté', 'Not connected', 'Sin conectar'),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy || _data?['available'] != true
                  ? null
                  : () => connect(p),
              child: Text(
                tr(
                  'Connecter / reconnecter',
                  'Connect / reconnect',
                  'Conectar / reconectar',
                ),
              ),
            ),
            if ((_data?['connections'] as List? ?? []).any(
              (c) => c['provider'] == p,
            )) ...[
              TextButton(
                onPressed: _busy ? null : () => select(p),
                child: Text(
                  tr(
                    'Choisir les calendriers',
                    'Choose calendars',
                    'Elegir calendarios',
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => disconnect(p),
                child: Text(tr('Déconnecter', 'Disconnect', 'Desconectar')),
              ),
            ],
          ],
        ),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: _busy || _data?['available'] != true ? null : finish,
            child: Text(
              tr(
                'Confirmer avec le code',
                'Confirm with code',
                'Confirmar con código',
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => run(refresh),
            child: Text(tr('Actualiser', 'Refresh', 'Actualizar')),
          ),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => run(() async {
                    final now = DateTime.now().toUtc();
                    final export = await widget.api
                        .call('exportDriverCalendar', {
                          'from': now
                              .subtract(const Duration(days: 30))
                              .toIso8601String(),
                          'to': now
                              .add(const Duration(days: 330))
                              .toIso8601String(),
                        });
                    final downloaded = await saveCalendarExport(
                      export['content'] as String,
                    );
                    if (mounted) {
                      setState(
                        () => _message = downloaded
                            ? tr(
                                'Fichier iCalendar téléchargé. Importez-le dans votre calendrier.',
                                'iCalendar downloaded. Import it into your calendar.',
                                'iCalendar descargado. Impórtalo a tu calendario.',
                              )
                            : tr(
                                'Contenu iCalendar copié. Enregistrez-le dans un fichier .ics.',
                                'iCalendar copied. Save it as an .ics file.',
                                'iCalendar copiado. Guárdalo como archivo .ics.',
                              ),
                      );
                    }
                  }),
            child: Text(
              tr(
                'Exporter pour Apple Calendar (.ics)',
                'Export for Apple Calendar (.ics)',
                'Exportar para Apple Calendar (.ics)',
              ),
            ),
          ),
        ],
      ),
      Text(
        tr(
          'Apple Calendar : export manuel seulement. Les modifications ne sont pas synchronisées et vos rendez-vous Apple ne bloquent pas les offres Movi-K.',
          'Apple Calendar: manual export only. Changes are not synchronized and Apple appointments do not block Movi-K offers.',
          'Apple Calendar: solo exportación manual. Los cambios no se sincronizan y las citas Apple no bloquean ofertas Movi-K.',
        ),
      ),
      if (_data?['checked_at'] != null)
        Text(
          '${tr('Dernière lecture', 'Last checked', 'Última consulta')} : ${DateTime.tryParse(_data!['checked_at'] as String)?.toLocal()} · ${state(_data!['busy_status'] as String)}',
        ),
      if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
    ],
  );
}
