/// تفاصيل طلبية واحدة كاملة: بيانات الطلب + المحل + العنوان + المنتجات.
class OrderDetailItem {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const OrderDetailItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory OrderDetailItem.fromMap(Map<String, dynamic> map) {
    return OrderDetailItem(
      productName: (map['products'] as Map<String, dynamic>)['name'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}

class CustomerOrderDetail {
  final String id;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final DateTime createdAt;
  final String merchantId;
  final String merchantName;
  final String? merchantPhone;
  final String communeName;
  final String addressText;
  final List<OrderDetailItem> items;

  const CustomerOrderDetail({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.createdAt,
    required this.merchantId,
    required this.merchantName,
    required this.merchantPhone,
    required this.communeName,
    required this.addressText,
    required this.items,
  });

  factory CustomerOrderDetail.fromMap(Map<String, dynamic> map) {
    final merchant = map['merchants'] as Map<String, dynamic>;
    final address = map['addresses'] as Map<String, dynamic>;
    final commune = address['communes'] as Map<String, dynamic>;
    final itemRows = map['order_items'] as List;

    return CustomerOrderDetail(
      id: map['id'] as String,
      status: map['status'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      deliveryFee: (map['delivery_fee'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      merchantId: merchant['id'] as String,
      merchantName: merchant['store_name'] as String,
      merchantPhone: merchant['phone'] as String?,
      communeName: commune['name'] as String,
      addressText: address['address_text'] as String,
      items: itemRows
          .map((row) => OrderDetailItem.fromMap(row as Map<String, dynamic>))
          .toList(),
    );
  }

  /// العميل يستطيع إلغاء طلبه بنفسه فقط طالما لم يوافق عليه التاجر بعد
  /// (نفس القاعدة المطبَّقة في trigger قاعدة البيانات — أنظر PHASE 1).
  bool get canBeCancelledByCustomer => status == 'pending';

  /// التقييم مسموح فقط لطلب سُلِّم فعليًا — نفس الشرط المطبَّق في RLS
  /// على جدول reviews (راجع migration reviews)، حتى لا يظهر زر تقييم
  /// يفشل عند الضغط عليه.
  bool get canBeReviewed => status == 'delivered';
}

/// تقييم عميل واحد لطلب مُسلَّم — قد لا يوجد بعد لطلب معيَّن (المستدعي
/// يتعامل مع null كـ "لم يُقيَّم بعد").
class CustomerReview {
  final String id;
  final int rating;
  final String? comment;

  const CustomerReview({required this.id, required this.rating, this.comment});

  factory CustomerReview.fromMap(Map<String, dynamic> map) {
    return CustomerReview(
      id: map['id'] as String,
      rating: (map['rating'] as num).toInt(),
      comment: map['comment'] as String?,
    );
  }
}
