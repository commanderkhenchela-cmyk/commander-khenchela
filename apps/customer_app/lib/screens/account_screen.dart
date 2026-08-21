import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/theme_controller.dart';
import 'address_list_screen.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';
import 'notifications_screen.dart';
import 'support_screen.dart';

/// شاشة "حسابي" — نقطة الدخول لتسجيل الدخول أو إدارة الحساب.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> _login() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.signOut();
    if (mounted) setState(() {});
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _showThemeSheet() async {
    final controller = context.read<ThemeController>();

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
                  child: Text(
                    'مظهر التطبيق',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                _ThemeModeOption(
                  icon: Icons.brightness_auto_rounded,
                  label: 'تلقائي (حسب إعداد الجهاز)',
                  selected: controller.mode == ThemeMode.system,
                  onTap: () {
                    controller.setMode(ThemeMode.system);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _ThemeModeOption(
                  icon: Icons.light_mode_rounded,
                  label: 'فاتح',
                  selected: controller.mode == ThemeMode.light,
                  onTap: () {
                    controller.setMode(ThemeMode.light);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _ThemeModeOption(
                  icon: Icons.dark_mode_rounded,
                  label: 'داكن',
                  selected: controller.mode == ThemeMode.dark,
                  onTap: () {
                    controller.setMode(ThemeMode.dark);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSignedIn = AuthService.isSignedIn;
    final themeMode = context.watch<ThemeController>().mode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('حسابي'),
        actions: [
          IconButton(
            icon: Icon(_themeModeIcon(themeMode)),
            tooltip: 'مظهر التطبيق',
            onPressed: _showThemeSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: isSignedIn ? _buildSignedIn(theme) : _buildSignedOut(theme),
      ),
    );
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  Widget _buildSignedIn(ThemeData theme) {
    final fullName =
        AuthService.currentUser?.userMetadata?['full_name'] as String? ?? '';
    final phone =
        AuthService.currentUser?.userMetadata?['phone'] as String? ?? '';
    final initial = fullName.isNotEmpty ? fullName.substring(0, 1) : '؟';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ---------- Header ----------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'مرحبًا بك' : fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ---------- Menu ----------
        _MenuGroup(
          children: [
            _MenuTile(
              icon: Icons.receipt_long_outlined,
              label: 'طلباتي',
              onTap: () => _push(const MyOrdersScreen()),
            ),
            _MenuTile(
              icon: Icons.notifications_none_rounded,
              label: 'إشعاراتي',
              onTap: () => _push(const NotificationsScreen()),
            ),
            _MenuTile(
              icon: Icons.favorite_border_rounded,
              label: 'مفضّلتي',
              onTap: () => _push(const FavoritesScreen()),
            ),
            _MenuTile(
              icon: Icons.location_on_outlined,
              label: 'عناويني',
              onTap: () => _push(const AddressListScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MenuGroup(
          children: [
            _MenuTile(
              icon: Icons.help_outline_rounded,
              label: 'المساعدة',
              onTap: () => _push(const SupportScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MenuGroup(
          children: [
            _MenuTile(
              icon: Icons.logout_rounded,
              label: 'تسجيل الخروج',
              color: theme.colorScheme.error,
              onTap: _logout,
              showChevron: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignedOut(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'سجّل الدخول لمتابعة طلباتك',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'وحفظ عناوينك ومتابعة إشعاراتك',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _login,
                child: const Text('تسجيل الدخول / إنشاء حساب'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _push(const SupportScreen()),
              child: const Text('المساعدة'),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة تجمع عدة عناصر قائمة مع فواصل بينها — نمط موحَّد لكل الشاشة.
class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showChevron;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = color ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? theme.colorScheme.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(color: tileColor),
              ),
            ),
            if (showChevron)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

/// خيار واحد داخل ورقة اختيار مظهر التطبيق (مظهر النظام/فاتح/داكن).
class _ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: selected ? theme.colorScheme.primary : null,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
