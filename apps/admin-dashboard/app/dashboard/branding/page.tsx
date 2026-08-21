import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { AppBranding } from "@/lib/types";
import BrandingForm from "./branding-form";

export default async function BrandingPage() {
  const context = await getAdminContext();
  if (!context?.isSuperAdmin) redirect("/dashboard");

  const supabase = await createClient();
  const { data: branding } = await supabase
    .from("app_branding")
    .select("id, app_name, logo_url, primary_color, error_color, updated_at")
    .eq("id", "default")
    .single();

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">الهوية والشعار</h1>
      <p className="text-sm text-black/60 mb-6">
        هذه البيانات تظهر مباشرة في تطبيق الزبون (شاشة البداية والألوان)
        فور الحفظ هنا — بدون الحاجة لأي تعديل في الكود أو نشر تحديث جديد
        للتطبيق.
      </p>
      <BrandingForm branding={branding as AppBranding} />
    </div>
  );
}
