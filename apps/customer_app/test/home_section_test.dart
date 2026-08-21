import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/models/home_section.dart';

void main() {
  group('HomeSectionKey.fromKey', () {
    test('يحوّل كل مفاتيح section_key المعروفة بشكل صحيح', () {
      expect(HomeSectionKey.fromKey('hero'), HomeSectionKey.hero);
      expect(HomeSectionKey.fromKey('categories'), HomeSectionKey.categories);
      expect(HomeSectionKey.fromKey('featured'), HomeSectionKey.featured);
      expect(HomeSectionKey.fromKey('nearby'), HomeSectionKey.nearby);
      expect(HomeSectionKey.fromKey('newest'), HomeSectionKey.newest);
      expect(
        HomeSectionKey.fromKey('most_ordered'),
        HomeSectionKey.mostOrdered,
      );
    });

    test('مفتاح غير معروف → unknown بدل استثناء يُسقط الصفحة', () {
      expect(HomeSectionKey.fromKey('something_new'), HomeSectionKey.unknown);
    });
  });

  group('HomeSection.fromMap', () {
    test('يبني القسم من صفّ قاعدة البيانات بشكل صحيح', () {
      final section = HomeSection.fromMap({
        'id': 'abc-123',
        'section_key': 'featured',
        'title': 'متاجر مميزة',
        'sort_order': 3,
      });

      expect(section.id, 'abc-123');
      expect(section.key, HomeSectionKey.featured);
      expect(section.title, 'متاجر مميزة');
      expect(section.sortOrder, 3);
    });
  });
}
