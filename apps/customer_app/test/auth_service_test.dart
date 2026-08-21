import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/services/auth_service.dart';

/// إثبات إصلاح خلل حقيقي: "0555123456" و"+213555123456" نفس الرقم
/// فعليًا (كلاهما مقبول في نماذج إنشاء الحساب والعنوان)، ويجب أن
/// ينتجا نفس البريد المموَّه — وإلا يفشل تسجيل الدخول لاحقًا بصيغة
/// مختلفة عن التي سجَّل بها العميل حسابه، رغم صحة كل البيانات.
void main() {
  group('AuthService.phoneToEmail', () {
    test('الصيغة المحلية والدولية لنفس الرقم تنتجان نفس البريد', () {
      final local = AuthService.phoneToEmail('0555123456');
      final international = AuthService.phoneToEmail('+213555123456');
      expect(local, equals(international));
    });

    test('الصيغة الدولية بدون + تُعامَل بنفس الطريقة', () {
      final local = AuthService.phoneToEmail('0555123456');
      final international = AuthService.phoneToEmail('213555123456');
      expect(local, equals(international));
    });

    test('رقمان مختلفان فعليًا ينتجان بريدين مختلفين', () {
      final first = AuthService.phoneToEmail('0555123456');
      final second = AuthService.phoneToEmail('0666987654');
      expect(first, isNot(equals(second)));
    });

    test('الصيغة المحلية تنتج البريد المتوقَّع بالضبط', () {
      expect(
        AuthService.phoneToEmail('0555123456'),
        '0555123456@phone.commanderkhenchela.local',
      );
    });
  });
}
