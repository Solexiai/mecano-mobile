import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/coming_soon_badge.dart';

class FaqScreen extends StatelessWidget {
  final String locale;
  const FaqScreen({super.key, required this.locale});

  String _tr({required String fr, required String en, required String es}) {
    switch (locale) {
      case 'en':
        return en;
      case 'es':
        return es;
      default:
        return fr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final faqs = <(String, String)>[
      (
        _tr(fr: 'Comment fonctionne le jumelage avec un fournisseur?', en: 'How does provider matching work?', es: '¿Cómo funciona el emparejamiento con un proveedor?'),
        _tr(
          fr: "Vous décrivez votre besoin (objet à livrer ou problème mécanique), puis Movi-k affiche les chauffeurs ou mécaniciens disponibles dans votre secteur. Vous choisissez celui qui vous convient et envoyez une demande de réservation.",
          en: 'You describe your need (item to deliver or mechanical problem), then Movi-k shows available drivers or mechanics in your area. You choose the one that suits you and send a booking request.',
          es: 'Describe su necesidad (artículo a entregar o problema mecánico), luego Movi-k muestra los conductores o mecánicos disponibles en su área. Elige el que le convenga y envía una solicitud de reserva.',
        ),
      ),
      (
        _tr(fr: 'Comment fonctionne le paiement?', en: 'How does payment work?', es: '¿Cómo funciona el pago?'),
        _tr(
          fr: "Au stade actuel (MVP), le paiement se fait directement entre vous et le fournisseur — comptant, virement Interac ou toute entente convenue. Le paiement intégré en ligne est en développement.",
          en: 'At this stage (MVP), payment happens directly between you and the provider — cash, Interac e-Transfer, or any agreed arrangement. Integrated online payment is under development.',
          es: 'En esta etapa (MVP), el pago se realiza directamente entre usted y el proveedor: efectivo, transferencia Interac o cualquier acuerdo pactado. El pago integrado en línea está en desarrollo.',
        ),
      ),
      (
        _tr(fr: 'Les fournisseurs sont-ils vérifiés?', en: 'Are providers verified?', es: '¿Los proveedores están verificados?'),
        _tr(
          fr: "Oui. Chaque chauffeur et mécanicien mobile doit soumettre une pièce d'identité et les documents requis (permis, assurance) avant d'être activé sur la plateforme.",
          en: 'Yes. Every driver and mobile mechanic must submit an ID and the required documents (licence, insurance) before being activated on the platform.',
          es: 'Sí. Cada conductor y mecánico móvil debe presentar una identificación y los documentos requeridos (licencia, seguro) antes de ser activado en la plataforma.',
        ),
      ),
      (
        _tr(fr: "Que se passe-t-il si l'objet ne rentre pas dans le véhicule prévu?", en: "What happens if the item doesn't fit the planned vehicle?", es: '¿Qué pasa si el artículo no cabe en el vehículo previsto?'),
        _tr(
          fr: "Décrivez les dimensions le plus précisément possible lors de la demande. Le chauffeur peut confirmer, ajuster ou refuser la demande selon la capacité réelle de son véhicule avant d'accepter la réservation.",
          en: 'Describe the dimensions as accurately as possible when making the request. The driver can confirm, adjust or decline the request based on their vehicle\'s actual capacity before accepting the booking.',
          es: 'Describa las dimensiones con la mayor precisión posible al hacer la solicitud. El conductor puede confirmar, ajustar o rechazar la solicitud según la capacidad real de su vehículo antes de aceptar la reserva.',
        ),
      ),
      (
        _tr(fr: 'Que se passe-t-il si le mécanicien a besoin de pièces?', en: 'What happens if the mechanic needs parts?', es: '¿Qué pasa si el mecánico necesita piezas?'),
        _tr(
          fr: "Le mécanicien vous informe des pièces nécessaires et du coût estimé. Pour le MVP, la commande de pièces est coordonnée manuellement entre vous, le mécanicien et notre équipe — aucune commande automatique n'est encore active.",
          en: 'The mechanic informs you of the parts needed and the estimated cost. For the MVP, parts ordering is coordinated manually between you, the mechanic and our team — no automatic ordering is active yet.',
          es: 'El mecánico le informa sobre las piezas necesarias y el costo estimado. Para el MVP, el pedido de piezas se coordina manualmente entre usted, el mecánico y nuestro equipo; aún no hay pedidos automáticos.',
        ),
      ),
      (
        _tr(fr: 'Le suivi GPS en temps réel est-il disponible?', en: 'Is real-time GPS tracking available?', es: '¿Está disponible el seguimiento GPS en tiempo real?'),
        _tr(
          fr: "Pas encore. Le suivi GPS en temps réel est une fonctionnalité à venir. Actuellement, vous communiquez directement avec le fournisseur pour connaître son statut.",
          en: 'Not yet. Real-time GPS tracking is a coming feature. Currently, you communicate directly with the provider to know their status.',
          es: 'Todavía no. El seguimiento GPS en tiempo real es una función próxima. Actualmente, se comunica directamente con el proveedor para conocer su estado.',
        ),
      ),
      (
        _tr(fr: "Comment devenir chauffeur ou mécanicien mobile?", en: 'How do I become a driver or mobile mechanic?', es: '¿Cómo me convierto en conductor o mecánico móvil?'),
        _tr(
          fr: "Cliquez sur « Devenir chauffeur » ou « Devenir mécanicien », remplissez le formulaire d'inscription (profil, véhicule ou spécialités, tarifs, documents) et attendez la vérification de votre profil.",
          en: 'Click "Become a Driver" or "Become a Mobile Mechanic", fill out the registration form (profile, vehicle or specialties, rates, documents) and wait for your profile to be verified.',
          es: 'Haga clic en "Convertirse en conductor" o "Convertirse en mecánico", complete el formulario de registro (perfil, vehículo o especialidades, tarifas, documentos) y espere la verificación de su perfil.',
        ),
      ),
      (
        _tr(fr: 'Puis-je annuler une réservation?', en: 'Can I cancel a booking?', es: '¿Puedo cancelar una reserva?'),
        _tr(
          fr: "Oui, l'annulation est gratuite jusqu'à 2 heures avant le rendez-vous convenu. Consultez notre page Sécurité pour les détails complets sur les règles d'annulation.",
          en: 'Yes, cancellation is free up to 2 hours before the agreed appointment. See our Safety page for full cancellation rule details.',
          es: 'Sí, la cancelación es gratuita hasta 2 horas antes de la cita acordada. Consulte nuestra página de Seguridad para más detalles sobre las reglas de cancelación.',
        ),
      ),
    ];

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: t('nav_faq')),
              const SizedBox(height: 32),
              ...faqs.map((f) => _FaqTile(question: f.$1, answer: f.$2)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tr(fr: "D'autres questions? Notre équipe est là pour vous aider.", en: 'More questions? Our team is here to help.', es: '¿Más preguntas? Nuestro equipo está aquí para ayudar.'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/$locale/contact'),
                      child: Text(t('nav_contact')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.gps_fixed, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_tr(fr: 'Suivi GPS en temps réel', en: 'Real-time GPS tracking', es: 'Seguimiento GPS en tiempo real'), style: const TextStyle(color: AppColors.textSecondary))),
                const ComingSoonBadge(small: true),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(answer, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}
