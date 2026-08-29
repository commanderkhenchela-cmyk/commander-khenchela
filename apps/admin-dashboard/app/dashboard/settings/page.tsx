import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { Setting } from "@/lib/types";
import SettingsForm from "./settings-form";

export default async function SettingsPage() {
  const context = await getAdminContext();
  if (!context?.isSuperAdmin) redirect("/dashboard");

  const supabase = await createClient();
  const { data: settings } = await supabase.rpc("admin_get_settings");

  const items = (settings ?? []) as Setting[];
  const commissionRate =
    items.find((s) => s.key === "platform_commission_rate")?.value ?? "10";

  return (
    <div className="max-w-md">
      <h1 className="text-2xl font-bold mb-1">إعدادات المنصة</h1>
      <p className="text-sm text-black/50 mb-6">
        كل إعداد هنا مقروء ومكتوب مباشرة من جدول settings عبر
        admin_get_settings/admin_set_setting — لا قيمة مُثبَّتة في الكود.
      </p>

      <p className="px-1 mb-2 text-[11px] font-bold uppercase tracking-wide text-black/40">
        عام
      </p>
      <div className="rounded-xl border border-border bg-card p-5 mb-6">
        <p className="font-semibold mb-1">نسبة عمولة المنصة</p>
        <p className="text-sm text-black/60 mb-4">
          تُطبَّق فقط على الطلبات الجديدة — لا تؤثر على طلبات سابقة (كل طلب
          يحتفظ بالنسبة وقت إنشائه).
        </p>
        <SettingsForm settingKey="platform_commission_rate" currentValue={commissionRate} unit="%" />
        <p className="text-xs text-black/40 mt-3">
          لاستثناء تاجر معيّن بنسبة مختلفة، اذهب لصفحة ذلك المحل — قسم
          &quot;عمولة هذا المحل&quot;.
        </p>
      </div>

      {/*
        فئات أخرى (التجار/الموصّلون/التوصيل/الإشعارات/الأمان) غير معروضة
        عمدًا: لا يوجد أي إعداد فعلي مخزَّن في جدول settings تحت هذه
        الفئات اليوم — عرض فئة فارغة هنا سيكون واجهة بلا بيانات حقيقية،
        وهو ما مُنِع صراحة في هذه المرحلة ("لا تُنشئ إعدادات
        Wallet/Fraud/Taxi أو أي فئة وهمية الآن"). تُضاف كل فئة فقط عند
        إضافة أول إعداد حقيقي تحتها.
      */}
    </div>
  );
}
