// أنواع بيانات تطابق جداول قاعدة البيانات (Supabase) المستخدَمة في لوحة التاجر.

export type MerchantStatus = "pending" | "approved" | "rejected";

export interface Merchant {
  id: string;
  owner_user_id: string;
  store_name: string;
  wilaya_id: number;
  commune_id: number;
  address_text: string | null;
  phone: string | null;
  status: MerchantStatus;
  latitude: number | null;
  longitude: number | null;
  created_at: string;
}

export interface Category {
  id: string;
  name: string;
  is_active: boolean;
}

export interface Product {
  id: string;
  merchant_id: string;
  category_id: string;
  name: string;
  description: string | null;
  price: number;
  is_active: boolean;
  created_at: string;
  product_images?: { id: string; image_url: string; sort_order: number }[];
}

export type OrderStatus =
  | "pending"
  | "confirmed"
  | "preparing"
  | "ready_for_pickup"
  | "picked_up"
  | "out_for_delivery"
  | "delivered"
  | "cancelled"
  | "rejected";

export const ORDER_STATUS_LABELS: Record<OrderStatus, string> = {
  pending: "بانتظار موافقتك",
  confirmed: "مؤكَّد",
  preparing: "قيد التجهيز",
  ready_for_pickup: "جاهز للاستلام",
  picked_up: "تم استلامه من المندوب",
  out_for_delivery: "في الطريق للعميل",
  delivered: "تم التسليم",
  cancelled: "ملغى",
  rejected: "مرفوض",
};

export interface OrderItem {
  id: string;
  product_id: string;
  quantity: number;
  unit_price: number;
  subtotal: number;
  products?: { name: string } | null;
}

export interface MerchantOrder {
  id: string;
  status: OrderStatus;
  subtotal: number;
  delivery_fee: number;
  total_amount: number;
  merchant_amount: number;
  created_at: string;
  addresses?: {
    address_text: string;
    communes?: { name: string } | null;
  } | null;
  order_items?: OrderItem[];
}

export interface Commune {
  id: number;
  name: string;
  wilaya_id: number;
}

/** 0=الأحد ... 6=السبت — راجع تعليق migration 20260821020000 للتفاصيل. */
export interface MerchantBusinessHours {
  id: string;
  merchant_id: string;
  day_of_week: number;
  open_time: string | null;
  close_time: string | null;
  is_closed: boolean;
}

export const DAY_NAMES = [
  "الأحد",
  "الاثنين",
  "الثلاثاء",
  "الأربعاء",
  "الخميس",
  "الجمعة",
  "السبت",
];

/** كود ولاية خنشلة الرسمي — المحل الوحيد المدعوم في V1. */
export const KHENCHELA_WILAYA_ID = 40;
