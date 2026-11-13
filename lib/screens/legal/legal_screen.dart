import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/booking/booking_contract.dart';
import '../../widgets/booking_terms_section.dart';

import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

/// Loads the published booking policy (system_config/booking_policy, served
/// to everyone by getBookingConfiguration). Null when none is published.
typedef LegalPolicyLoader = Future<Map<String, dynamic>?> Function();

Future<Map<String, dynamic>?> _firebasePolicyLoader() async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('getBookingConfiguration')
      .call(<String, dynamic>{});
  final data = result.data;
  if (data is! Map || data['policy'] is! Map) return null;
  return Map<String, dynamic>.from(data['policy'] as Map);
}

/// Public page type -> document of the published booking policy.
const _publishedDocumentFor = {
  'terms': 'terms',
  'cancellation': 'booking',
  'privacy': 'privacy',
};

/// Parameterized legal page. `type` selects which legal document to render:
/// privacy, terms, provider-agreement, cancellation, dispute, accessibility, cookies.
///
/// 2026-10-23: terms, cancellation and privacy show the SAME text the customer
/// accepts when booking (the published policy), so there is one version
/// everywhere. The hand-written text below is only a fallback when no policy
/// is published or it cannot be loaded.
class LegalScreen extends StatefulWidget {
  final String locale;
  final String type;
  final LegalPolicyLoader? policyLoader;
  const LegalScreen({
    super.key,
    required this.locale,
    required this.type,
    this.policyLoader,
  });

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String get locale => widget.locale;
  String get type => widget.type;
  BookingContract? _published;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LegalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Called before build: plain field writes, no setState needed.
    if (oldWidget.type != widget.type) _load();
  }

  Future<void> _load() async {
    // Plain field writes: _load also runs from initState/didUpdateWidget,
    // where setState is not allowed; the first build reads them.
    _published = null;
    _loading = _publishedDocumentFor.containsKey(type);
    if (!_loading) return;
    BookingContract? contract;
    try {
      contract = BookingContract.from(
        await (widget.policyLoader ?? _firebasePolicyLoader)(),
      );
    } catch (_) {
      contract = null; // Fallback text below; never a blank page.
    }
    if (!mounted) return;
    setState(() {
      _published = contract;
      _loading = false;
    });
  }

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
            fr: "Ces conditions régissent votre utilisation des services actuellement offerts par la plateforme Movi-K. Le parcours public concerne la livraison avec des chauffeurs indépendants.",
            en: 'These terms govern your use of the services currently offered through the Movi-K platform. The public flow concerns delivery with independent drivers.',
            es: 'Estos términos rigen el uso de los servicios ofrecidos actualmente mediante la plataforma Movi-K. El proceso público se centra en entregas con conductores independientes.',
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
            fr: "Cette entente décrit la relation entre Movi-K et les fournisseurs indépendants utilisant les services actuellement ouverts sur la plateforme. Elle concerne les chauffeurs de livraison.",
            en: 'This agreement describes the relationship between Movi-K and independent providers using services currently open on the platform. It applies to delivery drivers.',
            es: 'Este acuerdo describe la relación entre Movi-K y los proveedores independientes que utilizan los servicios actualmente abiertos en la plataforma. Se aplica a los conductores de entrega.',
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
        // Résumé des règles en vigueur (bookingDeposit.ts, missionFees.ts),
        // affiché seulement si les conditions de réservation publiées ne se
        // chargent pas. Service ouvert depuis novembre 2026.
        return (
          title: _tr(
            fr: "Politique d'annulation",
            en: 'Cancellation Policy',
            es: 'Política de cancelación',
          ),
          intro: _tr(
            fr: "Voici les règles d’annulation en vigueur. Le texte complet figure dans les conditions de réservation que vous acceptez à chaque réservation.",
            en: 'Here are the cancellation rules in force. The full text is in the booking terms you accept with each booking.',
            es: 'Estas son las reglas de cancelación vigentes. El texto completo figura en las condiciones de reserva que aceptas en cada reserva.',
          ),
          sections: [
            (
              _tr(
                fr: 'Votre dépôt de 25 \$',
                en: 'Your \$25 deposit',
                es: 'Tu depósito de 25 \$',
              ),
              _tr(
                fr: "Votre dépôt est remboursé si aucun chauffeur n’accepte, si vous annulez avant qu’un chauffeur accepte, ou si vous annulez plus de 48 heures avant le ramassage. Si un chauffeur a accepté et que le ramassage est dans moins de 48 heures, le dépôt est gardé.",
                en: 'Your deposit is refunded if no driver accepts, if you cancel before a driver accepts, or if you cancel more than 48 hours before pickup. If a driver has accepted and pickup is less than 48 hours away, the deposit is kept.',
                es: 'Tu depósito se reembolsa si ningún conductor acepta, si cancelas antes de que un conductor acepte o si cancelas más de 48 horas antes de la recogida. Si un conductor ya aceptó y la recogida es en menos de 48 horas, se conserva el depósito.',
              ),
            ),
            (
              _tr(
                fr: 'Déplacement inutile',
                en: 'Wasted trip',
                es: 'Desplazamiento en vano',
              ),
              _tr(
                fr: "Si le chauffeur se déplace pour rien à cause du client, des frais de 30 \$ s’appliquent.",
                en: 'If the driver makes a wasted trip because of the customer, a \$30 fee applies.',
                es: 'Si el conductor se desplaza en vano por causa del cliente, se aplica un cargo de 30 \$.',
              ),
            ),
            (
              _tr(
                fr: 'Avant de confirmer une demande',
                en: 'Before confirming a request',
                es: 'Antes de confirmar una solicitud',
              ),
              _tr(
                fr: "Les règles de paiement et d’annulation sont affichées avant que vous confirmiez votre réservation.",
                en: 'Payment and cancellation rules are shown before you confirm your booking.',
                es: 'Las reglas de pago y cancelación se muestran antes de que confirmes tu reserva.',
              ),
            ),
          ],
        );
      case 'dispute':
        // Règles décidées par Daniel le 10 nov. 2026 : signalement jusqu'à
        // 3 jours après la livraison, version du chauffeur sous 48 h,
        // révision à la main, Movi-K tranche.
        return (
          title: _tr(
            fr: 'Processus de litige',
            en: 'Dispute Process',
            es: 'Proceso de disputas',
          ),
          intro: _tr(
            fr: "Un problème avec une livraison ? Voici comment Movi‑K traite un litige.",
            en: 'A problem with a delivery? Here is how Movi‑K handles a dispute.',
            es: '¿Un problema con una entrega? Así es como Movi‑K gestiona una disputa.',
          ),
          sections: [
            (
              _tr(
                fr: 'Étape 1 — Signalement',
                en: 'Step 1 — Reporting',
                es: 'Paso 1 — Reporte',
              ),
              _tr(
                fr: "Écrivez-nous à infos@movi-k.com dans les 3 jours suivant la livraison, avec la référence de la livraison, une description du problème et vos photos.",
                en: 'Email us at infos@movi-k.com within 3 days after the delivery, with the delivery reference, a description of the problem and your photos.',
                es: 'Escríbenos a infos@movi-k.com dentro de los 3 días posteriores a la entrega, con la referencia de la entrega, una descripción del problema y tus fotos.',
              ),
            ),
            (
              _tr(
                fr: 'Étape 2 — Examen',
                en: 'Step 2 — Review',
                es: 'Paso 2 — Revisión',
              ),
              _tr(
                fr: "Movi‑K examine le dossier à la main : photos prises au ramassage et à la livraison, échanges, et version du chauffeur, qui a 48 heures pour répondre.",
                en: 'Movi‑K reviews the file by hand: photos taken at pickup and delivery, messages, and the driver’s account, who has 48 hours to reply.',
                es: 'Movi‑K revisa el expediente a mano: fotos tomadas al recoger y al entregar, mensajes y la versión del conductor, que tiene 48 horas para responder.',
              ),
            ),
            (
              _tr(
                fr: 'Étape 3 — Décision',
                en: 'Step 3 — Decision',
                es: 'Paso 3 — Decisión',
              ),
              _tr(
                fr: "Movi‑K tranche et vous informe de sa décision par courriel. S’il y a un remboursement, il est fait sur la carte utilisée pour la réservation.",
                en: 'Movi‑K decides and informs you by email. If there is a refund, it is made to the card used for the booking.',
                es: 'Movi‑K decide y te informa por correo electrónico. Si hay un reembolso, se hace en la tarjeta usada para la reserva.',
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
                fr: 'Photos de vos objets',
                en: 'Photos of your items',
                es: 'Fotos de sus objetos',
              ),
              _tr(
                fr: "Les photos que vous ajoutez à une demande sont analysées automatiquement par notre fournisseur OpenAI pour reconnaître l'article, puis montrées au chauffeur pour qu'il juge si tout entre dans son véhicule.",
                en: 'Photos you add to a request are analyzed automatically by our provider OpenAI to recognize the item, then shown to the driver so they can judge whether everything fits in their vehicle.',
                es: 'Las fotos que añade a una solicitud son analizadas automáticamente por nuestro proveedor OpenAI para reconocer el artículo, y luego se muestran al conductor para que juzgue si todo cabe en su vehículo.',
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

  Widget _publishedPage(BuildContext context, bool isDesktop, String key) {
    final contract = _published!;
    final doc = contract.document(key);
    final trial = contract.data['trial'] == true;
    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            key: const ValueKey('legal-published'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: bookingTermsLabel(locale, key)),
              const SizedBox(height: 8),
              Text(
                '${_tr(fr: 'Version', en: 'Version', es: 'Versión')} ${doc['version']}'
                '${trial ? _tr(fr: ' — version d’essai', en: ' — trial version', es: ' — versión de prueba') : ''}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (!(doc['content'] as Map).containsKey(locale))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Document en français / French document / Documento en francés',
                  ),
                ),
              const SizedBox(height: 24),
              SelectableText(
                contract.localized(doc['content'], locale),
                style: const TextStyle(height: 1.6, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final publishedKey = _publishedDocumentFor[type];
    if (publishedKey != null && _published != null) {
      return _publishedPage(context, isDesktop, publishedKey);
    }
    if (publishedKey != null && _loading) {
      return AppShell(
        locale: locale,
        child: const Padding(
          padding: EdgeInsets.all(64),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
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
                  fr: "Une question sur ce document ? Écrivez-nous à infos@movi-k.com.",
                  en: 'A question about this document? Email us at infos@movi-k.com.',
                  es: '¿Una pregunta sobre este documento? Escríbenos a infos@movi-k.com.',
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
