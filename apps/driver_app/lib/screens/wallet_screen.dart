import 'package:flutter/material.dart';

import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';
import '../widgets/state_message.dart';

/// محفظتي — للقراءة فقط (لا زر إيداع/خصم، هذا حصريًا من طرف الإدارة)،
/// نفس فلسفة merchant-dashboard/wallet/page.tsx بالحرف: بطاقة رصيد
/// علوية (= مجموع كل الحركات) + سجلّ الحركات. لا بوابة دفع إلكترونية —
/// الدفع/التحصيل يتم فـ مكتب الإدارة، والعمولة تُخصَم تلقائيًا عند
/// اكتمال كل مهمة (طلبية/رحلة Taxi/اطلب أي شيء) فعليًا.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<List<WalletTransaction>> _future;

  @override
  void initState() {
    super.initState();
    _future = WalletService.fetchTransactions();
  }

  Future<void> _refresh() async {
    setState(() => _future = WalletService.fetchTransactions());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('محفظتي')),
      body: FutureBuilder<List<WalletTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.wifi_off_rounded,
              message: 'تعذّر تحميل بيانات المحفظة.',
              action: ElevatedButton(
                onPressed: _refresh,
                child: const Text('إعادة المحاولة'),
              ),
            );
          }

          final transactions = snapshot.data ?? [];
          final balance = transactions.fold<double>(
            0,
            (sum, t) => sum + t.amount,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الرصيد الحالي'),
                      const SizedBox(height: 6),
                      Text(
                        '${balance.toStringAsFixed(2)} دج',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: balance < 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'لا يوجد بوابة دفع إلكترونية بعد — لتعبئة رصيدك، '
                        'ادفع المبلغ فـ مكتب الإدارة وسيُسجَّل هنا مباشرة. '
                        'تُخصَم عمولة كل مهمة تلقائيًا فور اكتمالها.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (transactions.isEmpty)
                const StateMessage(
                  icon: Icons.receipt_long_outlined,
                  message: 'لا توجد حركات مسجَّلة بعد.',
                )
              else
                ...transactions.map(
                  (t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  WalletTransaction.typeLabel(t.type),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (t.note != null && t.note!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    t.note!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(t.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${t.amount >= 0 ? '+' : ''}${t.amount.toStringAsFixed(2)} دج',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: t.amount >= 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
