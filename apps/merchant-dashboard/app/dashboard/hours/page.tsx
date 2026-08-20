import { getMerchantContext } from "@/lib/merchant-context";
import { createClient } from "@/lib/supabase/server";
import type { MerchantBusinessHours } from "@/lib/types";
import HoursForm from "./hours-form";

export default async function HoursPage() {
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  const supabase = await createClient();
  const { data: hours } = await supabase
    .from("merchant_business_hours")
    .select("id, merchant_id, day_of_week, open_time, close_time, is_closed")
    .eq("merchant_id", merchant.id)
    .order("day_of_week");

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">ساعات العمل</h1>
      <p className="text-black/60 mb-6 text-sm">
        تُستخدم لعرض شارة &quot;مفتوح الآن&quot; للعميل في التطبيق. اليوم الذي
        لا تحفظ له ساعات يبقى بدون شارة (لا نفترض أنه مغلق).
      </p>
      <HoursForm
        merchantId={merchant.id}
        initialHours={(hours ?? []) as MerchantBusinessHours[]}
      />
    </div>
  );
}
