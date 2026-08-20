import { getMerchantContext } from "@/lib/merchant-context";
import SettingsForm from "./settings-form";
import LocationForm from "./location-form";

export default async function SettingsPage() {
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  return (
    <div className="max-w-md">
      <h1 className="text-2xl font-bold mb-6">إعدادات المحل</h1>
      <SettingsForm merchant={merchant} />

      <div className="mt-8 rounded-xl border border-border bg-card p-5">
        <p className="font-semibold mb-3">الموقع الجغرافي</p>
        <LocationForm merchant={merchant} />
      </div>
    </div>
  );
}
