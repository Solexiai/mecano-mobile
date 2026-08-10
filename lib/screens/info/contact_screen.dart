import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class ContactScreen extends StatefulWidget {
  final String locale;
  const ContactScreen({super.key, required this.locale});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sent = false;

  String get locale => widget.locale;

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
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: t('nav_contact'),
                subtitle: _tr(
                  fr: "Une question, un problème ou une suggestion? Écrivez-nous.",
                  en: 'A question, an issue or a suggestion? Write to us.',
                  es: '¿Una pregunta, un problema o una sugerencia? Escríbanos.',
                ),
              ),
              const SizedBox(height: 32),
              isDesktop
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildForm(t)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildInfoCard()),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildForm(t),
                        const SizedBox(height: 24),
                        _buildInfoCard(),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(String Function(String) t) {
    if (_sent) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            const CircleAvatar(radius: 28, backgroundColor: AppColors.success, child: Icon(Icons.check, color: Colors.white, size: 28)),
            const SizedBox(height: 16),
            Text(
              _tr(fr: 'Message envoyé (démo)', en: 'Message sent (demo)', es: 'Mensaje enviado (demo)'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _tr(
                fr: "Ceci est une démonstration : aucun courriel réel n'a été envoyé. Notre équipe vous répondra habituellement en moins de 24 heures ouvrables.",
                en: 'This is a demo: no real email was sent. Our team usually replies within 24 business hours.',
                es: 'Esta es una demostración: no se envió ningún correo real. Nuestro equipo suele responder en menos de 24 horas hábiles.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() => _sent = false),
              child: Text(_tr(fr: 'Envoyer un autre message', en: 'Send another message', es: 'Enviar otro mensaje')),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: t('auth_full_name')),
              validator: (v) => (v == null || v.trim().isEmpty) ? t('common_required') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: t('auth_email')),
              validator: (v) => (v == null || !v.contains('@')) ? t('common_required') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectCtrl,
              decoration: InputDecoration(labelText: _tr(fr: 'Sujet', en: 'Subject', es: 'Asunto')),
              validator: (v) => (v == null || v.trim().isEmpty) ? t('common_required') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 5,
              decoration: InputDecoration(labelText: _tr(fr: 'Message', en: 'Message', es: 'Mensaje')),
              validator: (v) => (v == null || v.trim().isEmpty) ? t('common_required') : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _submit, child: Text(t('common_submit'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_tr(fr: 'Coordonnées', en: 'Contact details', es: 'Datos de contacto'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 16),
          _lightRow(Icons.mail_outline, 'support@movi-k.demo'),
          _lightRow(Icons.location_on_outlined, _tr(fr: 'Québec, Canada', en: 'Quebec, Canada', es: 'Quebec, Canadá')),
          _lightRow(Icons.schedule_outlined, _tr(fr: 'Réponse habituelle sous 24h ouvrables', en: 'Usual response within 24 business hours', es: 'Respuesta habitual en 24 horas hábiles')),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Text(
              _tr(
                fr: "Coordonnées de démonstration à des fins d'aperçu.",
                en: 'Demo contact details for preview purposes.',
                es: 'Datos de contacto de demostración con fines de vista previa.',
              ),
              style: const TextStyle(color: AppColors.textOnDarkSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lightRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
        ]),
      );
}
