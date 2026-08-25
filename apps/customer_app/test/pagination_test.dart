import 'package:customer_app/utils/pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasMorePages', () {
    test('صفحة ممتلئة بالكامل (== pageSize) → قد توجد صفحة تالية', () {
      expect(hasMorePages(fetchedCount: 20, pageSize: 20), isTrue);
    });

    test('صفحة أقل من pageSize → هذه آخر صفحة قطعًا', () {
      expect(hasMorePages(fetchedCount: 7, pageSize: 20), isFalse);
    });

    test('نتيجة فارغة (fetchedCount = 0) → لا صفحة تالية', () {
      expect(hasMorePages(fetchedCount: 0, pageSize: 20), isFalse);
    });

    test('حافة: عدد الصفوف الكلي مضاعف تمامًا لحجم الصفحة (لا فخّ)', () {
      // لو كان هناك بالضبط 40 صفًّا كليًا وpageSize=20: الصفحة الأولى
      // تُرجِع 20 (hasMore=true تفاؤليًا)، والصفحة الثانية تُرجِع 20
      // أيضًا (hasMore=true مرة أخرى) — الصفحة الثالثة (الفعلية) هي من
      // تُرجِع 0 وتُصحِّح الافتراض. هذا سلوك مقصود موثَّق في الدالة،
      // وليس عيبًا: يتفادى استعلام count إضافي لكل صفحة.
      expect(hasMorePages(fetchedCount: 20, pageSize: 20), isTrue);
      expect(hasMorePages(fetchedCount: 0, pageSize: 20), isFalse);
    });

    test('صفحة واحدة فقط بحجم 1 (pageSize=1) وامتلأت → قد توجد صفحة تالية', () {
      expect(hasMorePages(fetchedCount: 1, pageSize: 1), isTrue);
    });

    test('fetchedCount أكبر من pageSize (لا يجب أن يحدث فعليًا) → false دفاعيًا', () {
      // .range() في Supabase لا يمكن أن يُرجِع أكثر من الحجم المطلوب،
      // لكن الدالة تبقى صريحة (== فقط) بدل >= حتى تكشف أي استخدام خاطئ
      // بدل إخفائه بصمت.
      expect(hasMorePages(fetchedCount: 25, pageSize: 20), isFalse);
    });
  });
}
