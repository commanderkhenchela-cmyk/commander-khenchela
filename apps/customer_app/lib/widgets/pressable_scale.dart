import 'package:flutter/material.dart';

/// يضيف تأثير "انضغاط" بسيط (تصغير خفيف) لأي عنصر عند لمسه — يُستخدم مع
/// بطاقات قابلة للضغط (مثل بطاقة التصنيف) لإعطاء إحساس تفاعلي فوري، دون
/// إبطاء الاستجابة الفعلية للضغط (onTap يُنفَّذ عبر الـ InkWell الداخلي
/// كالمعتاد، هذا الويدجت لا يتحكم إلا بالتحريك البصري).
class PressableScale extends StatefulWidget {
  final Widget child;

  const PressableScale({super.key, required this.child});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
