import { createClient } from "@/lib/supabase/server";

export interface AdminContext {
  userId: string;
  fullName: string;
  isAdmin: boolean;
}

/**
 * يجلب المستخدم الحالي (إن وُجد) ويتحقق من أن دوره 'admin' في public.users.
 * حسابات الإدارة لا تُنشأ ذاتيًا من هذا التطبيق (لا صفحة تسجيل) — تُنشأ
 * يدويًا عبر Supabase Dashboard، أنظر README لهذا التطبيق.
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

  return {
    userId: user.id,
    fullName: profile?.full_name ?? "",
    isAdmin: profile?.role === "admin",
  };
}
