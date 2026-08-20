import { getMerchantContext } from "@/lib/merchant-context";
import SettingsForm from "./settings-form";

export default async function SettingsPage() {
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  return (
    <div className="max-w-md">
      <h1 className="text-2xl font-bold mb-6">إعدادات المحل</h1>
      <SettingsForm merchant={merchant} />
    </div>
  );
}
