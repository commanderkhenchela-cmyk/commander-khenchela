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
      <h1 className="text-2xl font-bold mb-6">إعدادات المنصة</h1>

      <div className="rounded-xl border border-border bg-card p-5">
        <p className="font-semibold mb-1">نسبة عمولة المنصة</p>
        <p className="text-sm text-black/60 mb-4">
          تُطبَّق فقط على الطلبات الجديدة — لا تؤثر على طلبات سابقة (كل طلب
          يحتفظ بالنسبة وقت إنشائه).
        </p>
        <SettingsForm settingKey="platform_commission_rate" currentValue={commissionRate} unit="%" />
      </div>
    </div>
  );
}
