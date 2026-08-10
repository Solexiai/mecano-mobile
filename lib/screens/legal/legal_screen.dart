import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

/// Parameterized legal page. `type` selects which legal document to render:
/// privacy, terms, provider-agreement, cancellation, dispute, accessibility, cookies.
class LegalScreen extends StatelessWidget {
  final String locale;
  final String type;
  const LegalScreen({super.key, required this.locale, required this.type});

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

  ({String title, String intro, List<(String, String)> sections}) _content() {
    switch (type) {
      case 'terms':
        return (
          title: _tr(fr: "Conditions d'utilisation", en: 'Terms of Service', es: 'Términos de servicio'),
          intro: _tr(
            fr: "Ces conditions régissent votre utilisation de la plateforme Movi-k, qui met en relation des clients avec des chauffeurs et mécaniciens mobiles indépendants.",
            en: 'These terms govern your use of the Movi-k platform, which connects customers with independent drivers and mobile mechanics.',
            es: 'Estos términos rigen el uso de la plataforma Movi-k, que conecta a los clientes con conductores y mecánicos móviles independientes.',
          ),
          sections: [
            (
              _tr(fr: 'Rôle de la plateforme', en: 'Role of the platform', es: 'Función de la plataforma'),
              _tr(
                fr: "Movi-k agit comme intermédiaire technologique entre clients et fournisseurs indépendants. Movi-k n'est pas l'employeur des fournisseurs et n'effectue pas elle-même les livraisons ou réparations.",
                en: 'Movi-k acts as a technology intermediary between customers and independent providers. Movi-k is not the employer of providers and does not itself perform deliveries or repairs.',
                es: 'Movi-k actúa como intermediario tecnológico entre clientes y proveedores independientes. Movi-k no es el empleador de los proveedores y no realiza entregas ni reparaciones por sí misma.',
              ),
            ),
            (
              _tr(fr: 'Comptes utilisateurs', en: 'User accounts', es: 'Cuentas de usuario'),
              _tr(
                fr: "Vous devez fournir des informations exactes lors de la création de votre compte et êtes responsable de la confidentialité de votre accès.",
                en: 'You must provide accurate information when creating your account and are responsible for keeping your access confidential.',
                es: 'Debe proporcionar información precisa al crear su cuenta y es responsable de mantener la confidencialidad de su acceso.',
              ),
            ),
            (
              _tr(fr: 'Obligations des fournisseurs', en: 'Provider obligations', es: 'Obligaciones de los proveedores'),
              _tr(
                fr: "Les fournisseurs doivent détenir les permis, assurances et qualifications requis par la loi pour exercer leur activité.",
                en: 'Providers must hold the licences, insurance and qualifications required by law to carry out their activity.',
                es: 'Los proveedores deben contar con las licencias, seguros y calificaciones exigidas por la ley para ejercer su actividad.',
              ),
            ),
            (
              _tr(fr: 'Limitation de responsabilité', en: 'Limitation of liability', es: 'Limitación de responsabilidad'),
              _tr(
                fr: "Movi-k n'est pas responsable des dommages, pertes ou litiges découlant directement d'un service rendu par un fournisseur indépendant, dans la mesure permise par la loi applicable.",
                en: 'Movi-k is not liable for damages, losses or disputes arising directly from a service performed by an independent provider, to the extent permitted by applicable law.',
                es: 'Movi-k no es responsable de daños, pérdidas o disputas derivadas directamente de un servicio realizado por un proveedor independiente, en la medida permitida por la ley aplicable.',
              ),
            ),
            (
              _tr(fr: 'Modification des conditions', en: 'Changes to terms', es: 'Modificación de los términos'),
              _tr(
                fr: "Ces conditions peuvent être mises à jour périodiquement. Les utilisateurs seront informés des changements importants.",
                en: 'These terms may be updated periodically. Users will be informed of significant changes.',
                es: 'Estos términos pueden actualizarse periódicamente. Los usuarios serán informados de cambios significativos.',
              ),
            ),
          ],
        );
      case 'provider-agreement':
        return (
          title: _tr(fr: 'Entente fournisseur', en: 'Provider Agreement', es: 'Acuerdo de proveedor'),
          intro: _tr(
            fr: "Cette entente précise la relation entre Movi-k et les fournisseurs indépendants (chauffeurs et mécaniciens mobiles) utilisant la plateforme.",
            en: 'This agreement outlines the relationship between Movi-k and independent providers (drivers and mobile mechanics) using the platform.',
            es: 'Este acuerdo describe la relación entre Movi-k y los proveedores independientes (conductores y mecánicos móviles) que utilizan la plataforma.',
          ),
          sections: [
            (
              _tr(fr: 'Statut de travailleur indépendant', en: 'Independent contractor status', es: 'Estatus de contratista independiente'),
              _tr(
                fr: "Les fournisseurs opèrent en tant que travailleurs indépendants, non comme employés de Movi-k. Ils déterminent leurs propres tarifs, horaires et zones de service.",
                en: 'Providers operate as independent contractors, not as Movi-k employees. They set their own rates, schedules and service areas.',
                es: 'Los proveedores operan como contratistas independientes, no como empleados de Movi-k. Establecen sus propias tarifas, horarios y áreas de servicio.',
              ),
            ),
            (
              _tr(fr: 'Vérification et documents', en: 'Verification and documents', es: 'Verificación y documentos'),
              _tr(
                fr: "Les fournisseurs doivent soumettre les documents requis (identité, permis, assurance) et les maintenir à jour pour rester actifs.",
                en: 'Providers must submit the required documents (identity, licence, insurance) and keep them current to remain active.',
                es: 'Los proveedores deben presentar los documentos requeridos (identidad, licencia, seguro) y mantenerlos actualizados para permanecer activos.',
              ),
            ),
            (
              _tr(fr: 'Rémunération future', en: 'Future monetization', es: 'Monetización futura'),
              _tr(
                fr: "L'inscription est actuellement gratuite. Une commission (8% à 12%) ou des frais d'abonnement pourront être introduits ultérieurement, avec préavis raisonnable.",
                en: 'Registration is currently free. A commission (8% to 12%) or subscription fees may be introduced later, with reasonable notice.',
                es: 'El registro es actualmente gratuito. Se podrá introducir una comisión (8% a 12%) o tarifas de suscripción más adelante, con aviso razonable.',
              ),
            ),
            (
              _tr(fr: 'Conduite et qualité de service', en: 'Conduct and service quality', es: 'Conducta y calidad del servicio'),
              _tr(
                fr: "Les fournisseurs s'engagent à un comportement professionnel, courtois et sécuritaire envers les clients.",
                en: 'Providers commit to professional, courteous and safe conduct toward customers.',
                es: 'Los proveedores se comprometen a una conducta profesional, cortés y segura hacia los clientes.',
              ),
            ),
          ],
        );
      case 'cancellation':
        return (
          title: _tr(fr: "Politique d'annulation", en: 'Cancellation Policy', es: 'Política de cancelación'),
          intro: _tr(
            fr: "Cette politique décrit les règles applicables lors de l'annulation d'une réservation de livraison ou de service mécanique.",
            en: 'This policy describes the rules that apply when cancelling a delivery or mechanic service booking.',
            es: 'Esta política describe las reglas aplicables al cancelar una reserva de entrega o de servicio mecánico.',
          ),
          sections: [
            (
              _tr(fr: 'Annulation gratuite', en: 'Free cancellation', es: 'Cancelación gratuita'),
              _tr(
                fr: "Vous pouvez annuler gratuitement jusqu'à 2 heures avant l'heure convenue du rendez-vous.",
                en: 'You may cancel free of charge up to 2 hours before the agreed appointment time.',
                es: 'Puede cancelar sin cargo hasta 2 horas antes de la hora de la cita acordada.',
              ),
            ),
            (
              _tr(fr: 'Annulation tardive', en: 'Late cancellation', es: 'Cancelación tardía'),
              _tr(
                fr: "Une annulation effectuée moins de 2 heures avant le rendez-vous peut entraîner des frais déterminés par le fournisseur.",
                en: 'A cancellation made less than 2 hours before the appointment may result in a fee set by the provider.',
                es: 'Una cancelación realizada con menos de 2 horas antes de la cita puede generar un cargo determinado por el proveedor.',
              ),
            ),
            (
              _tr(fr: 'Absence (no-show)', en: 'No-show', es: 'Ausencia (no-show)'),
              _tr(
                fr: "Si le client ou le fournisseur ne se présente pas sans préavis, cela peut affecter la note de fiabilité du compte concerné.",
                en: 'If the customer or provider fails to show up without notice, this may affect the reliability rating of the account involved.',
                es: 'Si el cliente o el proveedor no se presenta sin previo aviso, esto puede afectar la calificación de confiabilidad de la cuenta involucrada.',
              ),
            ),
          ],
        );
      case 'dispute':
        return (
          title: _tr(fr: 'Processus de litige', en: 'Dispute Process', es: 'Proceso de disputas'),
          intro: _tr(
            fr: "En cas de désaccord entre un client et un fournisseur, Movi-k propose un processus structuré de résolution.",
            en: 'In case of disagreement between a customer and a provider, Movi-k offers a structured resolution process.',
            es: 'En caso de desacuerdo entre un cliente y un proveedor, Movi-k ofrece un proceso estructurado de resolución.',
          ),
          sections: [
            (
              _tr(fr: 'Étape 1 — Signalement', en: 'Step 1 — Reporting', es: 'Paso 1 — Reporte'),
              _tr(fr: "Contactez le soutien Movi-k avec les détails de la réservation concernée et toute preuve pertinente (photos, messages).", en: 'Contact Movi-k support with the details of the booking involved and any relevant evidence (photos, messages).', es: 'Contacte al soporte de Movi-k con los detalles de la reserva involucrada y cualquier evidencia relevante (fotos, mensajes).'),
            ),
            (
              _tr(fr: 'Étape 2 — Examen', en: 'Step 2 — Review', es: 'Paso 2 — Revisión'),
              _tr(fr: "Un agent examine les deux versions des faits et peut demander des informations complémentaires.", en: 'An agent reviews both sides of the story and may request additional information.', es: 'Un agente revisa ambas versiones de los hechos y puede solicitar información adicional.'),
            ),
            (
              _tr(fr: 'Étape 3 — Résolution', en: 'Step 3 — Resolution', es: 'Paso 3 — Resolución'),
              _tr(fr: "Une décision équitable est communiquée aux deux parties, pouvant inclure un remboursement partiel, un avertissement ou une suspension du compte fournisseur.", en: 'A fair decision is communicated to both parties, which may include a partial refund, a warning, or suspension of the provider account.', es: 'Se comunica una decisión justa a ambas partes, que puede incluir un reembolso parcial, una advertencia o la suspensión de la cuenta del proveedor.'),
            ),
          ],
        );
      case 'accessibility':
        return (
          title: _tr(fr: "Accessibilité", en: 'Accessibility', es: 'Accesibilidad'),
          intro: _tr(
            fr: "Movi-k s'engage à rendre la plateforme accessible au plus grand nombre, conformément aux principes WCAG.",
            en: 'Movi-k is committed to making the platform accessible to as many people as possible, in line with WCAG principles.',
            es: 'Movi-k se compromete a que la plataforma sea accesible para la mayor cantidad de personas posible, conforme a los principios WCAG.',
          ),
          sections: [
            (
              _tr(fr: 'Contraste et lisibilité', en: 'Contrast and readability', es: 'Contraste y legibilidad'),
              _tr(fr: "Les couleurs et tailles de texte sont choisies pour assurer un contraste suffisant.", en: 'Colours and text sizes are chosen to ensure sufficient contrast.', es: 'Los colores y tamaños de texto se eligen para garantizar un contraste suficiente.'),
            ),
            (
              _tr(fr: 'Navigation au clavier', en: 'Keyboard navigation', es: 'Navegación con teclado'),
              _tr(fr: "Les principales fonctions sont accessibles au clavier sur la version web.", en: 'Main functions are accessible via keyboard on the web version.', es: 'Las funciones principales son accesibles mediante teclado en la versión web.'),
            ),
            (
              _tr(fr: 'Retour et amélioration continue', en: 'Feedback and continuous improvement', es: 'Retroalimentación y mejora continua'),
              _tr(fr: "Vous pouvez nous signaler tout obstacle d'accessibilité via la page Contact.", en: 'You can report any accessibility barrier via the Contact page.', es: 'Puede informarnos sobre cualquier barrera de accesibilidad a través de la página de Contacto.'),
            ),
          ],
        );
      case 'cookies':
        return (
          title: _tr(fr: 'Politique de cookies', en: 'Cookie Policy', es: 'Política de cookies'),
          intro: _tr(
            fr: "Cette politique explique comment Movi-k utilise les cookies et technologies similaires.",
            en: 'This policy explains how Movi-k uses cookies and similar technologies.',
            es: 'Esta política explica cómo Movi-k utiliza cookies y tecnologías similares.',
          ),
          sections: [
            (
              _tr(fr: 'Cookies essentiels', en: 'Essential cookies', es: 'Cookies esenciales'),
              _tr(fr: "Nécessaires au fonctionnement de base de la plateforme (session, langue, préférences).", en: 'Necessary for the basic functioning of the platform (session, language, preferences).', es: 'Necesarias para el funcionamiento básico de la plataforma (sesión, idioma, preferencias).'),
            ),
            (
              _tr(fr: 'Cookies analytiques', en: 'Analytics cookies', es: 'Cookies analíticas'),
              _tr(fr: "Utilisés pour comprendre l'usage global de la plateforme et l'améliorer.", en: 'Used to understand overall platform usage and improve it.', es: 'Se usan para comprender el uso general de la plataforma y mejorarla.'),
            ),
            (
              _tr(fr: 'Gestion des préférences', en: 'Managing preferences', es: 'Gestión de preferencias'),
              _tr(fr: "Vous pouvez gérer les cookies via les paramètres de votre navigateur.", en: 'You can manage cookies via your browser settings.', es: 'Puede gestionar las cookies mediante la configuración de su navegador.'),
            ),
          ],
        );
      case 'privacy':
      default:
        return (
          title: _tr(fr: 'Politique de confidentialité', en: 'Privacy Policy', es: 'Política de privacidad'),
          intro: _tr(
            fr: "Cette politique décrit comment Movi-k recueille, utilise et protège vos renseignements personnels.",
            en: 'This policy describes how Movi-k collects, uses and protects your personal information.',
            es: 'Esta política describe cómo Movi-k recopila, utiliza y protege su información personal.',
          ),
          sections: [
            (
              _tr(fr: 'Renseignements recueillis', en: 'Information collected', es: 'Información recopilada'),
              _tr(
                fr: "Nom, courriel, téléphone, ville, et informations liées aux demandes de service (description, adresses, préférences de rendez-vous).",
                en: 'Name, email, phone, city, and information related to service requests (description, addresses, appointment preferences).',
                es: 'Nombre, correo electrónico, teléfono, ciudad e información relacionada con las solicitudes de servicio (descripción, direcciones, preferencias de cita).',
              ),
            ),
            (
              _tr(fr: 'Utilisation des renseignements', en: 'Use of information', es: 'Uso de la información'),
              _tr(
                fr: "Vos renseignements sont utilisés pour faciliter le jumelage avec des fournisseurs, la communication et l'amélioration du service.",
                en: 'Your information is used to facilitate matching with providers, communication and service improvement.',
                es: 'Su información se utiliza para facilitar la vinculación con proveedores, la comunicación y la mejora del servicio.',
              ),
            ),
            (
              _tr(fr: 'Partage des données', en: 'Data sharing', es: 'Compartir datos'),
              _tr(
                fr: "Les informations nécessaires (nom, coordonnées, détails de la demande) sont partagées avec le fournisseur assigné à votre réservation, jamais vendues à des tiers.",
                en: 'Necessary information (name, contact details, request details) is shared with the provider assigned to your booking, and is never sold to third parties.',
                es: 'La información necesaria (nombre, datos de contacto, detalles de la solicitud) se comparte con el proveedor asignado a su reserva, y nunca se vende a terceros.',
              ),
            ),
            (
              _tr(fr: 'Conservation et sécurité', en: 'Retention and security', es: 'Retención y seguridad'),
              _tr(
                fr: "Les données sont conservées le temps nécessaire à la fourniture du service et protégées par des mesures de sécurité raisonnables.",
                en: 'Data is retained as long as necessary to provide the service and is protected by reasonable security measures.',
                es: 'Los datos se conservan durante el tiempo necesario para prestar el servicio y se protegen con medidas de seguridad razonables.',
              ),
            ),
            (
              _tr(fr: 'Vos droits', en: 'Your rights', es: 'Sus derechos'),
              _tr(
                fr: "Vous pouvez demander l'accès, la correction ou la suppression de vos renseignements personnels en nous contactant.",
                en: 'You may request access to, correction of, or deletion of your personal information by contacting us.',
                es: 'Puede solicitar el acceso, corrección o eliminación de su información personal contactándonos.',
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final content = _content();

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: content.title),
              const SizedBox(height: 8),
              Text(
                _tr(fr: 'Dernière mise à jour : document de démonstration', en: 'Last updated: demonstration document', es: 'Última actualización: documento de demostración'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              Text(content.intro, style: const TextStyle(color: AppColors.textSecondary, height: 1.6, fontSize: 15)),
              const SizedBox(height: 32),
              ...content.sections.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 8),
                        Text(s.$2, style: const TextStyle(color: AppColors.textSecondary, height: 1.6)),
                      ],
                    ),
                  )),
              const Divider(height: 40),
              Text(
                _tr(
                  fr: "Ce document est fourni à titre de démonstration pour l'aperçu de la plateforme Movi-k et ne constitue pas un avis juridique définitif.",
                  en: 'This document is provided for demonstration purposes as part of the Movi-k platform preview and does not constitute final legal advice.',
                  es: 'Este documento se proporciona con fines de demostración como parte de la vista previa de la plataforma Movi-k y no constituye asesoría legal definitiva.',
                ),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
