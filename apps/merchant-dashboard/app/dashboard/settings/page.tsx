import { getMerchantContext } from "@/lib/merchant-context";
import SettingsForm from "./settings-form";
import LocationForm from "./location-form";
import StoreImagesForm from "./store-images-form";
import { Card } from "@/components/ui/card";

export default async function SettingsPage() {
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  return (
    <div className="max-w-md">
      <h1 className="text-2xl font-bold mb-6">إعدادات المحل</h1>
      <SettingsForm merchant={merchant} />

      <Card className="mt-8">
        <p className="font-semibold mb-3">صور المحل</p>
        <StoreImagesForm merchant={merchant} />
      </Card>

      <Card className="mt-8">
        <p className="font-semibold mb-3">الموقع الجغرافي</p>
        <LocationForm merchant={merchant} />
      </Card>
    </div>
  );
}
