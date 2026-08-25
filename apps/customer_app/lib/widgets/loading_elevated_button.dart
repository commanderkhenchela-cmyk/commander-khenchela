import 'package:flutter/material.dart';

/// زر ElevatedButton مع حالة تحميل مدمَجة — يستبدل نمط "spinner صغير
/// بدل النص أثناء الحفظ/الإرسال" المكرَّر يدويًا في أكثر من شاشة
/// (تسجيل الدخول، إنشاء حساب، إتمام الطلب، حفظ عنوان...). جزء من
/// توسيع Design System (المرحلة الرابعة): نمط زر واحد قابل لإعادة
/// الاستخدام بدل أن تُعيد كل شاشة كتابة نفس الـ SizedBox+
/// CircularProgressIndicator يدويًا.
class LoadingElevatedButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget child;

  const LoadingElevatedButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : child,
    );
  }
}
