import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { Service } from "@/lib/types";
import ServiceActions from "./service-actions";

// نفس القائمة الموجودة داخل customer_app (lib/config/services.dart) —
// الخدمات التي بُنيت شاشاتها فعليًا. تفعيل خدمة غير موجودة هنا لا
// يكسر شيئًا (التطبيق يعرض "قريبًا")، لكن الأدمن يستحق معرفة ذلك قبل
// الضغط على "تفعيل" — راجع تعليق migration 20260824000000_services.
const BUILT_SERVICE_SLUGS = new Set(["marketplace", "restaurants"]);

export default async function ServicesPage() {
  const context = await getAdminContext();
  if (!context?.canManageStores) redirect("/dashboard");

  const supabase = await createClient();
  const { data: services } = await supabase
    .from("services")
    .select("id, slug, name, icon, description, enabled, sort_order, created_at, updated_at")
    .order("sort_order");

  const items = (services ?? []) as Service[];

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">الخدمات</h1>
      <p className="text-black/60 mb-6 text-sm">
        تتحكّم هنا بأي خدمة تظهر للعميل في الصفحة الرئيسية. الطاكسي والتوصيل
        والحرفيون قيد الإنشاء حاليًا — تفعيلها الآن يعرض للعميل رسالة
        &quot;قريبًا&quot; بدل شاشة فعلية، إلى أن يكتمل بناؤها.
      </p>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد خدمات — تحقّق من قاعدة البيانات.</p>
      ) : (
        <div className="grid gap-2">
          {items.map((service) => (
            <div
              key={service.id}
              className="rounded-xl border border-border bg-card p-4"
            >
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2 min-w-0">
                  <span className="text-2xl">{service.icon}</span>
                  <div className="min-w-0">
                    <p
                      className={`font-semibold ${
                        service.enabled ? "" : "text-black/40"
                      }`}
                    >
                      {service.name}
                    </p>
                    {service.description && (
                      <p className="text-xs text-black/50 truncate">
                        {service.description}
                      </p>
                    )}
                  </div>
                </div>
                {!BUILT_SERVICE_SLUGS.has(service.slug) && (
                  <span className="shrink-0 rounded-full bg-warning/10 text-warning text-xs font-medium px-2 py-0.5">
                    قيد الإنشاء
                  </span>
                )}
              </div>
              <div className="mt-3">
                <ServiceActions
                  serviceId={service.id}
                  enabled={service.enabled}
                />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
