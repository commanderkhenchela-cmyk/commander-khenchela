-- فهارس ناقصة على أعمدة تُستخدم فعليًا فـ استعلامات متكررة، لوحظت أثناء
-- مراجعة شاملة للبنية:
--   - order_items.product_id: أي تقرير "الأكثر مبيعًا" مستقبلي يفحصه.
--   - favorites.merchant_id: "كم شخص فضّل هذا المحل" — عكس الاتجاه
--     المفهرس حاليًا (favorites_user_id_idx يخدم "مفضّلاتي" فقط).

create index if not exists order_items_product_id_idx on order_items (product_id);
create index if not exists favorites_merchant_id_idx on favorites (merchant_id);
