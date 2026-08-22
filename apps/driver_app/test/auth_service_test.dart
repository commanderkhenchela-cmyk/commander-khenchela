import 'package:flutter_test/flutter_test.dart';

import 'package:driver_app/services/auth_service.dart';

/// نفس اختبارات AuthService.phoneToEmail في تطبيق الزبون حرفيًا — نفس
/// المنطق منسوخ هنا (لا package مشترك بين تطبيقات Flutter في هذا
/// المشروع)، فيجب أن يبقى مطابقًا لتفادي خلل تسجيل دخول بصيغة هاتف
/// مختلفة عن التي سجَّل بها الموصّل حسابه.
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
