import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';

class AuthScreen extends StatefulWidget {
  final String locale;
  const AuthScreen({super.key, required this.locale});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _linkSent = false;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<AuthProvider>();

    if (auth.isLoggedIn) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  '${t('auth_logged_in_as')} ${auth.currentUser!.fullName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      context.go('/${widget.locale}/tableau-de-bord'),
                  child: Text(t('nav_dashboard')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppShell(
      locale: widget.locale,
      showFooter: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  t('auth_welcome'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('auth_magic_link_desc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                if (!_linkSent) ...[
                  Text(
                    t('auth_choose_role'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text(t('auth_role_customer')),
                        selected: _role == UserRole.customer,
                        onSelected: (_) =>
                            setState(() => _role = UserRole.customer),
                      ),
                      ChoiceChip(
                        label: Text(t('auth_role_driver')),
                        selected: _role == UserRole.driver,
                        onSelected: (_) =>
                            setState(() => _role = UserRole.driver),
                      ),
                      ChoiceChip(
                        label: Text(t('auth_role_mechanic')),
                        selected: _role == UserRole.mechanic,
                        onSelected: (_) =>
                            setState(() => _role = UserRole.mechanic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: t('auth_full_name')),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: t('auth_email')),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: '${t('auth_phone')} (${t('common_optional')})',
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(t('auth_send_link')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t('auth_demo_notice'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: () => context.go('/${widget.locale}/admin'),
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 16,
                    ),
                    label: const Text(
                      'Accès administration (personnel autorisé)',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ] else
                  Column(
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 48,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('auth_check_inbox'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty)
      return;
    setState(() => _linkSent = true);
    final auth = context.read<AuthProvider>();
    await auth.signInOrRegister(
      email: _emailController.text.trim(),
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _role,
    );
    if (mounted) {
      if (_role == UserRole.driver) {
        context.go('/${widget.locale}/fournisseur/tableau-de-bord');
      } else if (_role == UserRole.mechanic) {
        context.go('/${widget.locale}/fournisseur/tableau-de-bord');
      } else {
        context.go('/${widget.locale}/tableau-de-bord');
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
