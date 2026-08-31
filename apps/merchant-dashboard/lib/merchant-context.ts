import { createClient } from "@/lib/supabase/server";
import type { Merchant } from "@/lib/types";

export interface MerchantContext {
  userId: string;
  merchant: Merchant | null;
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

  const { data: merchant } = await supabase
    .from("merchants")
    .select(
      "id, owner_user_id, store_name, wilaya_id, commune_id, address_text, phone, status, latitude, longitude, logo_url, cover_url, is_open, created_at",
    )
    .eq("owner_user_id", user.id)
    .maybeSingle();

  return { userId: user.id, merchant: merchant as Merchant | null };
}
