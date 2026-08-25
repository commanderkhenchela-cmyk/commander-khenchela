import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/branding_service.dart';
import '../services/locale_controller.dart';
import '../services/push_notification_service.dart';
import '../services/theme_controller.dart';
import '../theme/design_tokens.dart';
import 'support_screen.dart';

const String _prefsPushEnabledKey = 'push_enabled';

/// شاشة "الإعدادات" المستقلة — لم تكن موجودة إطلاقًا قبل هذه المرحلة
/// (كان تبديل المظهر فقط داخل شاشة "حسابي"). راجع تقرير الفحص للسياق.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;
  bool _loadingPushPref = true;

  @override
  void initState() {
    super.initState();
    _loadPushPref();
  }

  Future<void> _loadPushPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_prefsPushEnabledKey) ?? true;
      if (mounted) setState(() => _pushEnabled = value);
    } catch (_) {
      // يبقى الافتراضي (مفعَّل) — لا نعطّل الشاشة لأجل هذا.
    } finally {
      if (mounted) setState(() => _loadingPushPref = false);
    }
  }

  Future<void> _togglePush(bool value) async {
    setState(() => _pushEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsPushEnabledKey, value);
    } catch (_) {
      // فشل الحفظ لا يمنع التبديل بالجلسة الحالية.
    }

    if (value) {
      await PushNotificationService.enablePush();
    } else {
      await PushNotificationService.disablePush();
    }
  }

  Future<void> _showLanguageSheet() async {
    final controller = context.read<LocaleController>();
    final languageLabel = AppLocalizations.of(context).languageLabel;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      languageLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _LanguageOption(
                  label: 'العربية',
                  selected: controller.locale.languageCode == 'ar',
                  onTap: () {
                    controller.setLocale(const Locale('ar'));
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _LanguageOption(
                  label: 'Français',
                  selected: controller.locale.languageCode == 'fr',
                  onTap: () {
                    controller.setLocale(const Locale('fr'));
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _LanguageOption(
                  label: 'English',
                  selected: controller.locale.languageCode == 'en',
                  onTap: () {
                    controller.setLocale(const Locale('en'));
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  static const _languageNames = {
    'ar': 'العربية',
    'fr': 'Français',
    'en': 'English',
  };

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final localeController = context.watch<LocaleController>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsMenuLabel)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsGroup(
            title: l10n.appearanceGroupTitle,
            children: [
              _RadioTile(
                label: l10n.themeSystemLabel,
                selected: themeController.mode == ThemeMode.system,
                onTap: () => themeController.setMode(ThemeMode.system),
              ),
              _RadioTile(
                label: l10n.themeLightLabel,
                selected: themeController.mode == ThemeMode.light,
                onTap: () => themeController.setMode(ThemeMode.light),
              ),
              _RadioTile(
                label: l10n.themeDarkLabel,
                selected: themeController.mode == ThemeMode.dark,
                onTap: () => themeController.setMode(ThemeMode.dark),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: l10n.languageLabel,
            children: [
              _SettingsTile(
                icon: Icons.language_rounded,
                label: l10n.appLanguageLabel,
                trailing: _languageNames[localeController.locale.languageCode],
                onTap: _showLanguageSheet,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: l10n.notificationsGroupTitle,
            children: [
              SwitchListTile(
                value: _pushEnabled,
                onChanged: _loadingPushPref ? null : _togglePush,
                title: Text(l10n.orderNotificationsLabel),
                subtitle: Text(l10n.orderNotificationsSubtitle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                label: l10n.privacyPolicyLabel,
                onTap: () => _push(
                  _StaticInfoScreen(
                    title: l10n.privacyPolicyLabel,
                    body: l10n.privacyPolicyPlaceholderBody,
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                label: l10n.termsLabel,
                onTap: () => _push(
                  _StaticInfoScreen(
                    title: l10n.termsLabel,
                    body: l10n.termsPlaceholderBody,
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                label: l10n.helpMenuLabel,
                onTap: () => _push(const SupportScreen()),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                label: l10n.aboutAppLabel,
                onTap: () => _push(const _AboutScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _SettingsGroup({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 4),
            child: Text(
              title!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardAll,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[
            Text(
              trailing!,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _RadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _StaticInfoScreen extends StatelessWidget {
  final String title;
  final String body;

  const _StaticInfoScreen({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutAppLabel)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                BrandingService.appName,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l10n.versionLabel('1.0.0')),
              const SizedBox(height: 20),
              Text(
                l10n.appDescriptionAbout,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
