import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../theme/design_tokens.dart';
import '../features/settings/presentation/settings_screen.dart';
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.goBackAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.logoutTitle),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isSignedIn = AuthService.isSignedIn;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: SafeArea(
        child: isSignedIn
            ? _buildSignedIn(theme, l10n)
            : _buildSignedOut(theme, l10n),
      ),
    );
  }

  Widget _buildSignedIn(ThemeData theme, AppLocalizations l10n) {
    final fullName =
        AuthService.currentUser?.userMetadata?['full_name'] as String? ?? '';
    final phone =
        AuthService.currentUser?.userMetadata?['phone'] as String? ?? '';
    final initial = fullName.isNotEmpty
        ? fullName.substring(0, 1)
        : l10n.unknownInitial;

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
            borderRadius: AppRadius.pillAll,
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
                      fullName.isEmpty ? l10n.welcomeDefaultName : fullName,
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
              label: l10n.myOrdersTitle,
              onTap: () => _push(const MyOrdersScreen()),
            ),
            _MenuTile(
              icon: Icons.favorite_border_rounded,
              label: l10n.favoritesMenuLabel,
              onTap: () => _push(const FavoritesScreen()),
            ),
            _MenuTile(
              icon: Icons.location_on_outlined,
              label: l10n.addressesTitle,
              onTap: () => _push(const AddressListScreen()),
            ),
            _MenuTile(
              icon: Icons.notifications_none_rounded,
              label: l10n.notificationsMenuLabel,
              onTap: () => _push(const NotificationsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MenuGroup(
          children: [
            _MenuTile(
              icon: Icons.help_outline_rounded,
              label: l10n.helpMenuLabel,
              onTap: () => _push(const SupportScreen()),
            ),
            _MenuTile(
              icon: Icons.settings_outlined,
              label: l10n.settingsMenuLabel,
              onTap: () => _push(const SettingsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MenuGroup(
          children: [
            _MenuTile(
              icon: Icons.logout_rounded,
              label: l10n.logoutTitle,
              color: theme.colorScheme.error,
              onTap: _logout,
              showChevron: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignedOut(ThemeData theme, AppLocalizations l10n) {
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
              l10n.signInToContinueMessage,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.saveAddressesMessage,
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
                child: Text(l10n.loginOrSignupAction),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _push(const SupportScreen()),
              child: Text(l10n.helpMenuLabel),
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
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
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
