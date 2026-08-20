import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";
import { KHENCHELA_WILAYA_ID, type Commune } from "@/lib/types";
import OnboardingForm from "./onboarding-form";

export default async function OnboardingPage() {
  const context = await getMerchantContext();
  if (!context) redirect("/login");
  if (context.merchant) redirect("/");

  const supabase = await createClient();
  const { data: communes } = await supabase
    .from("communes")
    .select("id, name, wilaya_id")
    .eq("wilaya_id", KHENCHELA_WILAYA_ID)
    .order("name");

  return (
    <main className="flex flex-1 items-center justify-center p-6">
      <div className="w-full max-w-md rounded-2xl bg-card border border-border p-8 shadow-sm">
        <h1 className="text-2xl font-bold text-center mb-1">أنشئ محلك</h1>
        <p className="text-center text-sm text-black/60 mb-6">
          املأ بيانات محلك، وسيراجعها فريق الإدارة قبل ظهوره للعملاء.
        </p>

        <OnboardingForm communes={(communes ?? []) as Commune[]} />
      </div>
    </main>
  );
}
