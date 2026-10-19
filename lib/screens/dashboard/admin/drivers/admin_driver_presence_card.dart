import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/driver_presence.dart';

class AdminDriverPresenceCard extends StatelessWidget {
  const AdminDriverPresenceCard({super.key, required this.locale});
  final String locale;
  @override
  Widget build(BuildContext context) => DriverPresenceView(
    builder: (context, ids) => Card(
      child: InkWell(
        key: const Key('admin-connected-drivers'),
        onTap: () => context.go('/$locale/admin/chauffeurs?filter=connected'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.wifi_tethering),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale == 'fr'
                          ? 'Chauffeurs connectés'
                          : locale == 'es'
                          ? 'Conductores conectados'
                          : 'Connected drivers',
                    ),
                    Text(
                      ids?.length.toString() ?? '—',
                      semanticsLabel: ids == null
                          ? (locale == 'fr'
                                ? 'Présence indisponible'
                                : locale == 'es'
                                ? 'Presencia no disponible'
                                : 'Presence unavailable')
                          : null,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      locale == 'fr'
                          ? 'Signal de moins de 90 s · Voir la liste'
                          : locale == 'es'
                          ? 'Señal de menos de 90 s · Ver lista'
                          : 'Signal within 90 s · View list',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
}
