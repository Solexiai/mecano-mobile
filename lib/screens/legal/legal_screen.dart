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
          title: _tr(
            fr: "Conditions d'utilisation",
            en: 'Terms of Service',
            es: 'Términos de servicio',
          ),
          intro: _tr(
            fr: "Ces conditions régissent votre utilisation des services actuellement offerts par la plateforme Movi-K. Pour le lancement à Granby, le parcours public concerne la livraison avec des chauffeurs indépendants.",
            en: 'These terms govern your use of the services currently offered through the Movi-K platform. For the Granby launch, the public flow concerns delivery with independent drivers.',
            es: 'Estos términos rigen el uso de los servicios ofrecidos actualmente mediante la plataforma Movi-K. Para el lanzamiento en Granby, el proceso público se centra en entregas con conductores independientes.',
          ),
          sections: [
            (
              _tr(
                fr: 'Rôle de la plateforme',
                en: 'Role of the platform',
                es: 'Función de la plataforma',
              ),
              _tr(
                fr: "Movi-K agit comme intermédiaire technologique entre clients et chauffeurs indépendants pour le service de livraison actuellement présenté au public. Movi-K n'est pas l'employeur des chauffeurs et n'effectue pas elle-même les livraisons.",
                en: 'Movi-K acts as a technology intermediary between customers and independent drivers for the delivery service currently presented to the public. Movi-K is not the employer of drivers and does not itself perform deliveries.',
                es: 'Movi-K actúa como intermediario tecnológico entre clientes y conductores independientes para el servicio de entrega presentado actualmente al público. Movi-K no es el empleador de los conductores y no realiza las entregas por sí misma.',
              ),
            ),
            (
              _tr(
                fr: 'Comptes utilisateurs',
                en: 'User accounts',
                es: 'Cuentas de usuario',
              ),
              _tr(
                fr: "Vous devez fournir des informations exactes lors de la création de votre compte et êtes responsable de la confidentialité de votre accès.",
                en: 'You must provide accurate information when creating your account and are responsible for keeping your access confidential.',
                es: 'Debe proporcionar información precisa al crear su cuenta y es responsable de mantener la confidencialidad de su acceso.',
              ),
            ),
            (
              _tr(
                fr: 'Obligations des fournisseurs',
                en: 'Provider obligations',
                es: 'Obligaciones de los proveedores',
              ),
              _tr(
                fr: "Les fournisseurs doivent détenir les permis, assurances et qualifications requis par la loi pour exercer leur activité.",
                en: 'Providers must hold the licences, insurance and qualifications required by law to carry out their activity.',
                es: 'Los proveedores deben contar con las licencias, seguros y calificaciones exigidas por la ley para ejercer su actividad.',
              ),
            ),
            (
              _tr(
                fr: 'Limitation de responsabilité',
                en: 'Limitation of liability',
                es: 'Limitación de responsabilidad',
              ),
              _tr(
                fr: "Movi-k n'est pas responsable des dommages, pertes ou litiges découlant directement d'un service rendu par un fournisseur indépendant, dans la mesure permise par la loi applicable.",
                en: 'Movi-k is not liable for damages, losses or disputes arising directly from a service performed by an independent provider, to the extent permitted by applicable law.',
                es: 'Movi-k no es responsable de daños, pérdidas o disputas derivadas directamente de un servicio realizado por un proveedor independiente, en la medida permitida por la ley aplicable.',
              ),
            ),
            (
              _tr(
                fr: 'Modification des conditions',
                en: 'Changes to terms',
                es: 'Modificación de los términos',
              ),
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
          title: _tr(
            fr: 'Entente fournisseur',
            en: 'Provider Agreement',
            es: 'Acuerdo de proveedor',
          ),
          intro: _tr(
            fr: "Cette entente décrit la relation entre Movi-K et les fournisseurs indépendants utilisant les services actuellement ouverts sur la plateforme. Le lancement public visé ici concerne les chauffeurs de livraison.",
            en: 'This agreement describes the relationship between Movi-K and independent providers using services currently open on the platform. The public launch covered here concerns delivery drivers.',
            es: 'Este acuerdo describe la relación entre Movi-K y los proveedores independientes que utilizan los servicios actualmente abiertos en la plataforma. El lanzamiento público tratado aquí corresponde a conductores de entrega.',
          ),
          sections: [
            (
              _tr(
                fr: 'Statut de travailleur indépendant',
                en: 'Independent contractor status',
                es: 'Estatus de contratista independiente',
              ),
              _tr(
                fr: "Les fournisseurs opèrent en tant que travailleurs indépendants, non comme employés de Movi‑K. La tarification des missions affichée au client est calculée par la plateforme selon la configuration serveur; elle n’est pas fixée manuellement par le chauffeur.",
                en: 'Providers operate as independent contractors, not as Movi‑K employees. Mission pricing shown to customers is calculated by the platform from server configuration; it is not manually set by the driver.',
                es: 'Los proveedores operan como contratistas independientes, no como empleados de Movi‑K. El precio mostrado al cliente se calcula en la plataforma según la configuración del servidor; no lo fija manualmente el conductor.',
              ),
            ),
            (
              _tr(
                fr: 'Vérification et documents',
                en: 'Verification and documents',
                es: 'Verificación y documentos',
              ),
              _tr(
                fr: "Les fournisseurs doivent soumettre les documents requis (identité, permis, assurance) et les maintenir à jour pour rester actifs.",
                en: 'Providers must submit the required documents (identity, licence, insurance) and keep them current to remain active.',
                es: 'Los proveedores deben presentar los documentos requeridos (identidad, licencia, seguro) y mantenerlos actualizados para permanecer activos.',
              ),
            ),
            (
              _tr(
                fr: 'Rémunération et frais de plateforme',
                en: 'Driver compensation and platform fees',
                es: 'Remuneración y cargos de plataforma',
              ),
              _tr(
                fr: "Les règles de rémunération, de commission et de versement applicables doivent correspondre à la configuration financière approuvée et aux conditions en vigueur. Aucun taux non approuvé n’est fixé par ce document.",
                en: 'Applicable compensation, commission and payout rules must match the approved financial configuration and current terms. This document does not set any unapproved rate.',
                es: 'Las reglas aplicables de remuneración, comisión y pago deben corresponder a la configuración financiera aprobada y a las condiciones vigentes. Este documento no fija ninguna tasa no aprobada.',
              ),
            ),
            (
              _tr(
                fr: 'Conduite et qualité de service',
                en: 'Conduct and service quality',
                es: 'Conducta y calidad del servicio',
              ),
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
          title: _tr(
            fr: "Politique d'annulation",
            en: 'Cancellation Policy',
            es: 'Política de cancelación',
          ),
          intro: _tr(
            fr: "Les modalités commerciales d’annulation sont encore en révision avant le lancement public. Ce document indique l’état actuel sans inventer de délai ni de frais.",
            en: 'Commercial cancellation terms are still under review before public launch. This document states the current status without inventing a window or fee.',
            es: 'Las condiciones comerciales de cancelación siguen en revisión antes del lanzamiento público. Este documento indica el estado actual sin inventar plazos ni cargos.',
          ),
          sections: [
            (
              _tr(
                fr: 'Politique en révision',
                en: 'Policy under review',
                es: 'Política en revisión',
              ),
              _tr(
                fr: "Les délais, frais et conditions commerciales d’annulation ne sont pas encore approuvés pour publication. Aucun délai gratuit ni frais fixe n’est annoncé à ce stade.",
                en: 'Commercial cancellation windows, fees and conditions are not yet approved for publication. No free-cancellation window or fixed fee is advertised at this stage.',
                es: 'Los plazos, cargos y condiciones comerciales de cancelación aún no están aprobados para publicación. No se anuncia ningún plazo gratuito ni cargo fijo en esta etapa.',
              ),
            ),
            (
              _tr(
                fr: 'Avant de confirmer une demande',
                en: 'Before confirming a request',
                es: 'Antes de confirmar una solicitud',
              ),
              _tr(
                fr: "Les conditions applicables devront être présentées clairement dans le parcours avant qu’une réservation publique soit ouverte. Cette page ne remplace pas une politique commerciale approuvée.",
                en: 'Applicable terms must be presented clearly in the flow before public booking opens. This page does not replace an approved commercial policy.',
                es: 'Las condiciones aplicables deberán mostrarse claramente en el proceso antes de abrir reservas públicas. Esta página no sustituye una política comercial aprobada.',
              ),
            ),
          ],
        );
      case 'dispute':
        return (
          title: _tr(
            fr: 'Processus de litige',
            en: 'Dispute Process',
            es: 'Proceso de disputas',
          ),
          intro: _tr(
            fr: "Le processus commercial de traitement des litiges est encore en préparation avant l’ouverture publique. Cette page décrit uniquement les éléments à prévoir et ne constitue pas une promesse de prise en charge actuellement disponible.",
            en: 'The commercial dispute-handling process is still being prepared before public launch. This page only describes items to be defined and does not promise a support process that is currently available.',
            es: 'El proceso comercial de gestión de disputas sigue en preparación antes de la apertura pública. Esta página solo describe elementos que deben definirse y no promete un proceso de soporte disponible actualmente.',
          ),
          sections: [
            (
              _tr(
                fr: 'Étape 1 — Signalement',
                en: 'Step 1 — Reporting',
                es: 'Paso 1 — Reporte',
              ),
              _tr(
                fr: "Conservez les détails de la mission et les preuves pertinentes, comme les photos ou messages. Le canal officiel de signalement doit encore être publié avant l’ouverture du service.",
                en: 'Keep the mission details and relevant evidence, such as photos or messages. The official reporting channel still needs to be published before service opens.',
                es: 'Conserva los detalles de la misión y las pruebas pertinentes, como fotos o mensajes. El canal oficial de reporte todavía debe publicarse antes de la apertura del servicio.',
              ),
            ),
            (
              _tr(
                fr: 'Étape 2 — Examen',
                en: 'Step 2 — Review',
                es: 'Paso 2 — Revisión',
              ),
              _tr(
                fr: "Les rôles, délais et critères d’examen doivent encore être approuvés. Aucun délai de traitement n’est annoncé à ce stade.",
                en: 'Review roles, timelines and criteria still need approval. No handling time is advertised at this stage.',
                es: 'Los roles, plazos y criterios de revisión todavía deben aprobarse. En esta etapa no se anuncia ningún plazo de gestión.',
              ),
            ),
            (
              _tr(
                fr: 'Étape 3 — Résolution',
                en: 'Step 3 — Resolution',
                es: 'Paso 3 — Resolución',
              ),
              _tr(
                fr: "Les mesures possibles et leurs critères, y compris tout remboursement ou mesure sur un compte, doivent être définis dans la politique finale et respecter les règles financières approuvées.",
                en: 'Possible outcomes and their criteria, including any refund or account action, must be defined in the final policy and follow approved financial rules.',
                es: 'Las medidas posibles y sus criterios, incluido cualquier reembolso o acción sobre una cuenta, deben definirse en la política final y respetar las reglas financieras aprobadas.',
              ),
            ),
          ],
        );
      case 'accessibility':
        return (
          title: _tr(
            fr: "Accessibilité",
            en: 'Accessibility',
            es: 'Accesibilidad',
          ),
          intro: _tr(
            fr: "Movi-k s'engage à rendre la plateforme accessible au plus grand nombre, conformément aux principes WCAG.",
            en: 'Movi-k is committed to making the platform accessible to as many people as possible, in line with WCAG principles.',
            es: 'Movi-k se compromete a que la plataforma sea accesible para la mayor cantidad de personas posible, conforme a los principios WCAG.',
          ),
          sections: [
            (
              _tr(
                fr: 'Contraste et lisibilité',
                en: 'Contrast and readability',
                es: 'Contraste y legibilidad',
              ),
              _tr(
                fr: "Les couleurs et tailles de texte sont choisies pour assurer un contraste suffisant.",
                en: 'Colours and text sizes are chosen to ensure sufficient contrast.',
                es: 'Los colores y tamaños de texto se eligen para garantizar un contraste suficiente.',
              ),
            ),
            (
              _tr(
                fr: 'Navigation au clavier',
                en: 'Keyboard navigation',
                es: 'Navegación con teclado',
              ),
              _tr(
                fr: "Les principales fonctions sont accessibles au clavier sur la version web.",
                en: 'Main functions are accessible via keyboard on the web version.',
                es: 'Las funciones principales son accesibles mediante teclado en la versión web.',
              ),
            ),
            (
              _tr(
                fr: 'Retour et amélioration continue',
                en: 'Feedback and continuous improvement',
                es: 'Retroalimentación y mejora continua',
              ),
              _tr(
                fr: "Vous pouvez nous signaler tout obstacle d'accessibilité via la page Contact.",
                en: 'You can report any accessibility barrier via the Contact page.',
                es: 'Puede informarnos sobre cualquier barrera de accesibilidad a través de la página de Contacto.',
              ),
            ),
          ],
        );
      case 'cookies':
        return (
          title: _tr(
            fr: 'Politique de cookies',
            en: 'Cookie Policy',
            es: 'Política de cookies',
          ),
          intro: _tr(
            fr: "Cette politique explique comment Movi-k utilise les cookies et technologies similaires.",
            en: 'This policy explains how Movi-k uses cookies and similar technologies.',
            es: 'Esta política explica cómo Movi-k utiliza cookies y tecnologías similares.',
          ),
          sections: [
            (
              _tr(
                fr: 'Cookies essentiels',
                en: 'Essential cookies',
                es: 'Cookies esenciales',
              ),
              _tr(
                fr: "Nécessaires au fonctionnement de base de la plateforme (session, langue, préférences).",
                en: 'Necessary for the basic functioning of the platform (session, language, preferences).',
                es: 'Necesarias para el funcionamiento básico de la plataforma (sesión, idioma, preferencias).',
              ),
            ),
            (
              _tr(
                fr: 'Cookies analytiques',
                en: 'Analytics cookies',
                es: 'Cookies analíticas',
              ),
              _tr(
                fr: "Utilisés pour comprendre l'usage global de la plateforme et l'améliorer.",
                en: 'Used to understand overall platform usage and improve it.',
                es: 'Se usan para comprender el uso general de la plataforma y mejorarla.',
              ),
            ),
            (
              _tr(
                fr: 'Gestion des préférences',
                en: 'Managing preferences',
                es: 'Gestión de preferencias',
              ),
              _tr(
                fr: "Vous pouvez gérer les cookies via les paramètres de votre navigateur.",
                en: 'You can manage cookies via your browser settings.',
                es: 'Puede gestionar las cookies mediante la configuración de su navegador.',
              ),
            ),
          ],
        );
      case 'privacy':
      default:
        return (
          title: _tr(
            fr: 'Politique de confidentialité',
            en: 'Privacy Policy',
            es: 'Política de privacidad',
          ),
          intro: _tr(
            fr: "Cette politique décrit comment Movi-k recueille, utilise et protège vos renseignements personnels.",
            en: 'This policy describes how Movi-k collects, uses and protects your personal information.',
            es: 'Esta política describe cómo Movi-k recopila, utiliza y protege su información personal.',
          ),
          sections: [
            (
              _tr(
                fr: 'Renseignements recueillis',
                en: 'Information collected',
                es: 'Información recopilada',
              ),
              _tr(
                fr: "Nom, courriel, téléphone, ville, et informations liées aux demandes de service (description, adresses, préférences de rendez-vous).",
                en: 'Name, email, phone, city, and information related to service requests (description, addresses, appointment preferences).',
                es: 'Nombre, correo electrónico, teléfono, ciudad e información relacionada con las solicitudes de servicio (descripción, direcciones, preferencias de cita).',
              ),
            ),
            (
              _tr(
                fr: 'Utilisation des renseignements',
                en: 'Use of information',
                es: 'Uso de la información',
              ),
              _tr(
                fr: "Vos renseignements sont utilisés pour faciliter le jumelage avec des fournisseurs, la communication et l'amélioration du service.",
                en: 'Your information is used to facilitate matching with providers, communication and service improvement.',
                es: 'Su información se utiliza para facilitar la vinculación con proveedores, la comunicación y la mejora del servicio.',
              ),
            ),
            (
              _tr(
                fr: 'Partage des données',
                en: 'Data sharing',
                es: 'Compartir datos',
              ),
              _tr(
                fr: "Les informations nécessaires (nom, coordonnées, détails de la demande) sont partagées avec le fournisseur assigné à votre réservation, jamais vendues à des tiers.",
                en: 'Necessary information (name, contact details, request details) is shared with the provider assigned to your booking, and is never sold to third parties.',
                es: 'La información necesaria (nombre, datos de contacto, detalles de la solicitud) se comparte con el proveedor asignado a su reserva, y nunca se vende a terceros.',
              ),
            ),
            (
              _tr(
                fr: 'Conservation et sécurité',
                en: 'Retention and security',
                es: 'Retención y seguridad',
              ),
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
                _tr(
                  fr: 'Document en révision avant lancement public',
                  en: 'Document under review before public launch',
                  es: 'Documento en revisión antes del lanzamiento público',
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                content.intro,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.6,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),
              ...content.sections.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.$2,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 40),
              Text(
                _tr(
                  fr: "Ce document est une version de travail en révision avant lancement. Les modalités commerciales et juridiques finales doivent être approuvées avant l’ouverture publique.",
                  en: 'This document is a working draft under review before launch. Final commercial and legal terms must be approved before public opening.',
                  es: 'Este documento es un borrador en revisión antes del lanzamiento. Las condiciones comerciales y legales finales deben aprobarse antes de la apertura pública.',
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
