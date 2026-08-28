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
  category_id: string | null;
  is_featured: boolean;
  orders_count: number;
  logo_url: string | null;
  cover_url: string | null;
  created_at: string;
  communes?: { name: string } | null;
  merchant_categories?: { name: string; icon: string } | null;
}

export interface Category {
  id: string;
  name: string;
  is_active: boolean;
  created_at: string;
}

/// تصنيفات المحلات (مطاعم، بقالة...) — مختلفة عن Category أعلاه التي
/// تصنّف المنتجات *داخل* محل واحد. انظر تعليق migration
/// 20260820090000_merchant_categories.sql للتفاصيل الكاملة.
export interface MerchantCategory {
  id: string;
  name: string;
  icon: string;
  sort_order: number;
  is_active: boolean;
  parent_id: string | null;
  service_id: string;
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
  drivers?: { full_name: string; phone: string } | null;
}

/// موصّلو التوصيل (المرحلة 1 — دراجات فقط). راجع migration
/// 20260822010000_drivers.sql للتفاصيل الكاملة (RLS، الحماية من التعديل
/// المباشر، ربطها بجدول orders عبر driver_id).
export type DriverStatus = "pending" | "approved" | "rejected";

export interface Driver {
  id: string;
  user_id: string;
  full_name: string;
  phone: string;
  vehicle_type: "bike";
  status: DriverStatus;
  is_online: boolean;
  created_at: string;
}

export interface Setting {
  key: string;
  value: string;
  updated_at: string;
}

export interface AppBranding {
  id: string;
  app_name: string;
  logo_url: string | null;
  primary_color: string;
  error_color: string;
  updated_at: string;
}

export interface ActivityLogEntry {
  id: string;
  admin_name: string;
  action: string;
  table_name: string;
  record_id: string | null;
  created_at: string;
}

const TABLE_LABELS: Record<string, string> = {
  merchants: "محل",
  drivers: "موصّل",
  orders: "طلب",
  app_branding: "الهوية والشعار",
  app_contact: "بيانات التواصل",
  categories: "تصنيف",
  merchant_categories: "تصنيف محلات",
  advertisements: "إعلان",
  users: "دور مستخدم",
  home_sections: "قسم الصفحة الرئيسية",
  services: "خدمة",
};

export function tableLabel(tableName: string): string {
  return TABLE_LABELS[tableName] ?? tableName;
}

export type UserRole = "customer" | "merchant" | "admin" | "manager" | "ads_manager";

export interface TeamMember {
  id: string;
  full_name: string;
  phone: string | null;
  role: UserRole;
  created_at: string;
}

export const ROLE_LABELS: Record<UserRole, string> = {
  customer: "عميل",
  merchant: "تاجر",
  admin: "مدير عام (صلاحية كاملة)",
  manager: "مدير",
  ads_manager: "مدير الإعلانات",
};

export const ADMIN_PANEL_ROLES: UserRole[] = ["admin", "manager", "ads_manager"];

export type HomeSectionKey =
  | "hero"
  | "categories"
  | "featured"
  | "nearby"
  | "newest"
  | "most_ordered"
  | "most_viewed";

export const HOME_SECTION_KEY_LABELS: Record<HomeSectionKey, string> = {
  hero: "الإعلانات (أعلى الصفحة)",
  categories: "التصنيفات",
  featured: "متاجر مميزة",
  nearby: "بالقرب منك",
  newest: "جديد في خنشلة",
  most_ordered: "الأكثر طلبًا",
  most_viewed: "الأكثر مشاهدة",
};

export interface HomeSection {
  id: string;
  section_key: HomeSectionKey;
  title: string;
  sort_order: number;
  is_active: boolean;
  created_at: string;
}

export type ServiceSlug =
  | "marketplace"
  | "restaurants"
  | "taxi"
  | "delivery"
  | "craftsmen";

export interface Service {
  id: string;
  slug: ServiceSlug;
  name: string;
  icon: string;
  description: string | null;
  enabled: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export interface Advertisement {
  id: string;
  title: string;
  description: string | null;
  advertiser_name: string;
  video_url: string;
  thumbnail_url: string | null;
  link_url: string | null;
  start_date: string | null;
  end_date: string | null;
  sort_order: number;
  is_active: boolean;
  views_count: number;
  video_starts_count: number;
  video_completions_count: number;
  clicks_count: number;
  created_at: string;
}

export interface AppContact {
  id: string;
  whatsapp_number: string;
  display_phone: string;
  support_email: string;
  facebook_url: string | null;
  instagram_url: string | null;
  updated_at: string;
}

/** إشعار واحد — نفس جدول notifications المستخدَم في تطبيق الزبون
 * (راجع migration 20260819050823 وشبكة الإشعارات 20260822000000).
 * تُنشأ فقط من طرف السيرفر، RLS تحصر القراءة على صاحبها. */
export interface AppNotification {
  id: string;
  title: string;
  body: string;
  type: string | null;
  is_read: boolean;
  created_at: string;
  entity_type: string | null;
  entity_id: string | null;
}
