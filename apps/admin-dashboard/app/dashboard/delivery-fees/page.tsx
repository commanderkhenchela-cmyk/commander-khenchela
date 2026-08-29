import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { DeliveryFeeConfig, DeliveryFeeZonePrice, Service } from "@/lib/types";
import DeliveryFeeConfigForm from "./delivery-fee-config-form";
import ZonePriceTable from "./zone-price-table";

/**
 * رسوم التوصيل — إعدادات عامة لكل خدمة (سعر ثابت / حسب المسافة / حسب
 * البلدية) + حصة الموصّل. لا رسم يدوي لكل طلب بعد الآن — راجع migration
 * 20260901000000_delivery_fee_engine للمحرك الفعلي. صفحة مستقلة (لا
 * صفحة الإعدادات العامة) لأن هذا إعداد متعدد الحقول لكل خدمة، بخلاف
 * القيمة الرقمية الواحدة التي يناسبها SettingsForm.
 */
export default async function DeliveryFeesPage() {
  const context = await getAdminContext();
  if (!context?.hasCapability("settings.manage")) redirect("/dashboard");

  const supabase = await createClient();
  const [{ data: services }, { data: configs }, { data: zonePrices }, { data: communes }] =
    await Promise.all([
      supabase
        .from("services")
        .select("id, slug, name, icon, description, enabled, sort_order, created_at, updated_at")
        .order("sort_order"),
      supabase
        .from("delivery_fee_configs")
        .select(
          "service_id, method, fixed_amount, distance_base_amount, distance_per_km_amount, driver_share_type, driver_share_value, enabled, updated_at",
        ),
      supabase
        .from("delivery_fee_zone_prices")
        .select("id, service_id, commune_id, price, updated_at"),
      supabase.from("communes").select("id, name").order("name"),
    ]);

  const servicesList = (services ?? []) as Service[];
  const configsByService = new Map(
    ((configs ?? []) as DeliveryFeeConfig[]).map((c) => [c.service_id, c]),
  );
  const zonePricesList = (zonePrices ?? []) as DeliveryFeeZonePrice[];
  const communesList = (communes ?? []) as { id: number; name: string }[];

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-bold mb-1">رسوم التوصيل</h1>
      <p className="text-sm text-black/50 mb-6">
        كل خدمة لها إعداد رسوم مستقل. لا رسم يُحدَّد يدويًا لكل طلب بعد
        الآن — النظام يحسب رسم كل طلب تلقائيًا وقت إنشائه وفق الإعداد
        هنا، ويحفظه كرقم ثابت لا يتغيّر لاحقًا حتى لو عدَّلت الإعداد.
        خدمة بلا إعداد = رسم صفري (نفس السلوك السابق) حتى تُهيَّئها.
      </p>

      <div className="grid gap-4">
        {servicesList.map((service) => (
          <div
            key={service.id}
            className="rounded-xl border border-border bg-card p-5"
          >
            <div className="flex items-center gap-2 mb-3">
              <span className="text-xl">{service.icon}</span>
              <p className="font-semibold">{service.name}</p>
            </div>
            <DeliveryFeeConfigForm
              serviceId={service.id}
              config={configsByService.get(service.id) ?? null}
            />
            <div className="mt-4 pt-4 border-t border-border">
              <ZonePriceTable
                serviceId={service.id}
                communes={communesList}
                prices={zonePricesList.filter((p) => p.service_id === service.id)}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
