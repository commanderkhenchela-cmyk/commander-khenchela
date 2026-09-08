import { createClient } from "@/lib/supabase/server";
import type { Merchant } from "@/lib/types";

export interface MerchantContext {
  userId: string;
  merchant: Merchant | null;
  /** users.is_suspended لصاحب الحساب — راجع migration
   * 20260831000000_fraud_system. لا يمنع الدخول هنا (enforcement
   * الفعلي عبر RLS/triggers فـ create_order وتوابعه، ومنذ migration
   * 20260909000000 أيضًا فـ تقدّم حالة orders)، فقط يُستخدَم لعرض شريط
   * تنبيه واضح فـ الهيدر (StoreStatusToggle موقعه الحالي) بدل ترك
   * التاجر يظنّ أن حسابه يعمل بشكل طبيعي. */
  isSuspended: boolean;
}

/**
 * يجلب المستخدم الحالي (إن وُجد) وملف محله (إن وُجد).
 * يُستخدم في كل صفحة تحتاج معرفة "أين يقف" التاجر في رحلته:
 * غير مسجَّل → لا يوجد محل بعد → قيد المراجعة → مرفوض → موافَق عليه.
 */
export async function getMerchantContext(): Promise<MerchantContext | null> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const [{ data: merchant }, { data: profile }] = await Promise.all([
    supabase
      .from("merchants")
      .select(
        "id, owner_user_id, store_name, wilaya_id, commune_id, address_text, phone, status, latitude, longitude, logo_url, cover_url, is_open, created_at",
      )
      .eq("owner_user_id", user.id)
      .maybeSingle(),
    supabase.from("users").select("is_suspended").eq("id", user.id).maybeSingle(),
  ]);

  return {
    userId: user.id,
    merchant: merchant as Merchant | null,
    isSuspended: profile?.is_suspended === true,
  };
}
