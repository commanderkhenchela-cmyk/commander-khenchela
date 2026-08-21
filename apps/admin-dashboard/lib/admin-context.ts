import { createClient } from "@/lib/supabase/server";

export type AdminRole = "admin" | "manager" | "ads_manager";

export interface AdminContext {
  userId: string;
  fullName: string;
  role: AdminRole | null;
  /** Super Admin فقط — صلاحية كاملة. */
  isSuperAdmin: boolean;
  /** يدخل لوحة الإدارة أصلًا (أحد الأدوار الثلاثة). */
  isAdmin: boolean;
  /** يدير المحلات/تصنيفاتها/تصنيفات المنتجات — Super Admin أو Manager. */
  canManageStores: boolean;
  /** يدير الإعلانات — Super Admin أو Manager أو Ads Manager. */
  canManageAds: boolean;
}

const ADMIN_ROLES = new Set(["admin", "manager", "ads_manager"]);

/**
 * يجلب المستخدم الحالي (إن وُجد) ويتحقق من دوره في public.users.
 * حسابات الإدارة لا تُنشأ ذاتيًا من هذا التطبيق (لا صفحة تسجيل) — أول
 * حساب Super Admin يُنشأ يدويًا عبر Supabase Dashboard (أنظر README)،
 * وبعدها يدير باقي الفريق من صفحة "الفريق" هنا.
 */
export async function getAdminContext(): Promise<AdminContext | null> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data: profile } = await supabase
    .from("users")
    .select("role, full_name")
    .eq("id", user.id)
    .maybeSingle();

  const role = profile?.role ?? null;
  const isAdmin = role !== null && ADMIN_ROLES.has(role);

  return {
    userId: user.id,
    fullName: profile?.full_name ?? "",
    role: isAdmin ? (role as AdminRole) : null,
    isSuperAdmin: role === "admin",
    isAdmin,
    canManageStores: role === "admin" || role === "manager",
    canManageAds:
      role === "admin" || role === "manager" || role === "ads_manager",
  };
}
