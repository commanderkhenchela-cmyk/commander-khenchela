/// ساعات عمل محل ليوم واحد من أيام الأسبوع، مطابق لجدول
/// merchant_business_hours. dayOfWeek: 0=الأحد ... 6=السبت (نفس ترقيم
/// DateTime.weekday % 7 في Dart، راجع MerchantOpenStatus).
class MerchantBusinessHours {
  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;

  const MerchantBusinessHours({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  factory MerchantBusinessHours.fromMap(Map<String, dynamic> map) {
    return MerchantBusinessHours(
      dayOfWeek: map['day_of_week'] as int,
      openTime: map['open_time'] as String?,
      closeTime: map['close_time'] as String?,
      isClosed: map['is_closed'] as bool? ?? false,
    );
  }
}
