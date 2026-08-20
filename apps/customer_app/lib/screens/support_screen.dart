import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/support_config.dart';

/// شاشة "المساعدة" — أسئلة شائعة + طرق تواصل مباشرة، بدون الحاجة
/// لأي حساب أو بحث في الإعدادات.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _openWhatsapp() async {
    final uri = Uri.parse('https://wa.me/${SupportConfig.whatsappNumber}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call() async {
    final uri = Uri.parse('tel:${SupportConfig.whatsappNumber}');
    await launchUrl(uri);
  }

  Future<void> _email() async {
    final uri = Uri.parse('mailto:${SupportConfig.supportEmail}');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('المساعدة')),
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
                      'تواصل معنا',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ContactRow(
                      icon: Icons.chat_bubble_outline,
                      label: 'واتساب',
                      value: SupportConfig.displayPhone,
                      onTap: _openWhatsapp,
                    ),
                    _ContactRow(
                      icon: Icons.call_outlined,
                      label: 'اتصال',
                      value: SupportConfig.displayPhone,
                      onTap: _call,
                    ),
                    _ContactRow(
                      icon: Icons.email_outlined,
                      label: 'البريد الإلكتروني',
                      value: SupportConfig.supportEmail,
                      onTap: _email,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'أسئلة شائعة',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const _FaqTile(
              question: 'كيف أتابع حالة طلبي؟',
              answer: 'من "حسابي" ← "طلباتي"، اضغط على أي طلب لمتابعة حالته لحظة بلحظة.',
            ),
            const _FaqTile(
              question: 'هل يمكنني إلغاء طلبي؟',
              answer:
                  'نعم، طالما التاجر لم يوافق على الطلب بعد (الحالة "قيد المراجعة"). '
                  'بعد الموافقة، يُرجى التواصل معنا مباشرة.',
            ),
            const _FaqTile(
              question: 'كيف أدفع ثمن طلبي؟',
              answer: 'الدفع عند الاستلام فقط (نقدًا للمندوب عند وصول الطلب).',
            ),
            const _FaqTile(
              question: 'هل تخدمون خارج ولاية خنشلة؟',
              answer:
                  'حاليًا خدمتنا متاحة فقط داخل ولاية خنشلة، وسنتوسع قريبًا.',
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
