// أنواع بيانات تطابق جداول قاعدة البيانات (Supabase) المستخدَمة في لوحة الإدارة.

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
  created_at: string;
  communes?: { name: string } | null;
}

export interface Category {
  id: string;
  name: string;
  is_active: boolean;
  created_at: string;
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
  pending: "بانتظار موافقة التاجر",
  confirmed: "مؤكَّد من التاجر",
  preparing: "قيد التجهيز",
  ready_for_pickup: "جاهز للاستلام",
  picked_up: "تم الاستلام من المحل",
  out_for_delivery: "في الطريق للعميل",
  delivered: "تم التسليم",
  cancelled: "ملغى",
  rejected: "مرفوض من التاجر",
};

export interface OrderItem {
  id: string;
  product_id: string;
  quantity: number;
  unit_price: number;
  subtotal: number;
  products?: { name: string } | null;
}

export interface AdminOrder {
  id: string;
  status: OrderStatus;
  subtotal: number;
  delivery_fee: number;
  total_amount: number;
  merchant_amount: number;
  platform_commission_amount: number;
  created_at: string;
  merchants?: { store_name: string; phone: string | null } | null;
  addresses?: {
    address_text: string;
    phone: string | null;
    communes?: { name: string } | null;
  } | null;
  order_items?: OrderItem[];
}

export interface Setting {
  key: string;
  value: string;
  updated_at: string;
}
