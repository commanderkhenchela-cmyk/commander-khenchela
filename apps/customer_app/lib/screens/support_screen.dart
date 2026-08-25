import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/contact_service.dart';

/// شاشة "المساعدة" — أسئلة شائعة + طرق تواصل مباشرة، بدون الحاجة
/// لأي حساب أو بحث في الإعدادات. بيانات التواصل تُحمَّل من لوحة الإدارة
/// (ContactService) — لا حاجة لتعديل هذا الملف عند تغيير رقم أو بريد.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _openWhatsapp() async {
    final uri = Uri.parse('https://wa.me/${ContactService.whatsappNumber}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call() async {
    final uri = Uri.parse('tel:${ContactService.whatsappNumber}');
    await launchUrl(uri);
  }

  Future<void> _email() async {
    final uri = Uri.parse('mailto:${ContactService.supportEmail}');
    await launchUrl(uri);
  }

  Future<void> _openLink(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final facebook = ContactService.facebookUrl;
    final instagram = ContactService.instagramUrl;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpMenuLabel)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.contactUsTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ContactRow(
                      icon: Icons.chat_bubble_outline,
                      label: l10n.whatsappLabel,
                      value: ContactService.displayPhone,
                      onTap: _openWhatsapp,
                    ),
                    _ContactRow(
                      icon: Icons.call_outlined,
                      label: l10n.callLabel,
                      value: ContactService.displayPhone,
                      onTap: _call,
                    ),
                    _ContactRow(
                      icon: Icons.email_outlined,
                      label: l10n.emailLabel,
                      value: ContactService.supportEmail,
                      onTap: _email,
                    ),
                    if (facebook != null && facebook.isNotEmpty)
                      _ContactRow(
                        icon: Icons.facebook_outlined,
                        label: l10n.facebookLabel,
                        value: l10n.facebookPageValue,
                        onTap: () => _openLink(facebook),
                      ),
                    if (instagram != null && instagram.isNotEmpty)
                      _ContactRow(
                        icon: Icons.camera_alt_outlined,
                        label: l10n.instagramLabel,
                        value: l10n.instagramAccountValue,
                        onTap: () => _openLink(instagram),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.faqTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _FaqTile(
              question: l10n.faqTrackOrderQuestion,
              answer: l10n.faqTrackOrderAnswer,
            ),
            _FaqTile(
              question: l10n.faqCancelOrderQuestion,
              answer: l10n.faqCancelOrderAnswer,
            ),
            _FaqTile(
              question: l10n.faqPaymentQuestion,
              answer: l10n.faqPaymentAnswer,
            ),
            _FaqTile(
              question: l10n.faqCoverageQuestion,
              answer: l10n.faqCoverageAnswer,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(answer, textAlign: TextAlign.right),
            ),
          ),
        ],
      ),
    );
  }
}
