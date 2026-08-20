import '../models/merchant_business_hours.dart';

/// يحسب هل المحل "مفتوح الآن" اعتمادًا على ساعات عمله المحفوظة، بالوقت
/// المحلي للجهاز (خنشلة على توقيت واحد ثابت طوال السنة UTC+1، بلا
/// توقيت صيفي، فالوقت المحلي للجهاز كافٍ وصادق هنا).
///
/// يُرجع null عندما لا نملك معلومة كافية (التاجر لم يحفظ ساعات عمله
/// بعد، أو لم يحفظ ساعات لليوم الحالي تحديدًا) — الشاشات يجب أن تُخفي
/// أي شارة في هذه الحالة، لا أن تفترض "مغلق" ظلمًا بالمحل.
class MerchantOpenStatus {
  const MerchantOpenStatus._();

  static bool? isOpenNow(List<MerchantBusinessHours> hours, {DateTime? now}) {
    if (hours.isEmpty) return null;

    final current = now ?? DateTime.now();
    final todayIndex = current.weekday % 7; // 0=الأحد...6=السبت

    MerchantBusinessHours? today;
    for (final h in hours) {
      if (h.dayOfWeek == todayIndex) {
        today = h;
        break;
      }
    }
    if (today == null) return null;
    if (today.isClosed) return false;
    if (today.openTime == null || today.closeTime == null) return null;

    final nowMinutes = current.hour * 60 + current.minute;
    final open = _toMinutes(today.openTime!);
    final close = _toMinutes(today.closeTime!);
    if (open == null || close == null) return null;

    // لا ندعم ساعات عمل تمتد لما بعد منتصف الليل في V1 (مثلاً
    // 22:00 -> 02:00) — حالة نادرة لنوع المحلات المستهدَفة حاليًا.
    if (close <= open) return null;

    return nowMinutes >= open && nowMinutes < close;
  }

  /// يحوّل نصًا بصيغة "HH:MM" أو "HH:MM:SS" (كما يعيدها Postgres لنوع
  /// time) إلى عدد دقائق منذ منتصف الليل.
  static int? _toMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
}
