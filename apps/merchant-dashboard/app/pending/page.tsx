import { redirect } from "next/navigation";
import { getMerchantContext } from "@/lib/merchant-context";
import LogoutButton from "@/components/logout-button";
import { AuthCard } from "@/components/ui/auth-card";
import { HourglassIcon } from "@/components/ui/icons";

export default async function PendingPage() {
  const context = await getMerchantContext();
  if (!context) redirect("/login");
  if (!context.merchant) redirect("/onboarding");
  if (context.merchant.status !== "pending") redirect("/");

  return (
    <AuthCard className="text-center">
      <HourglassIcon className="h-12 w-12 mx-auto mb-4 text-warning" />
      <h1 className="text-xl font-bold mb-2">محلك قيد المراجعة</h1>
      <p className="text-black/70">
        أرسلنا طلبك لفريق الإدارة. سنُعلمك فور الموافقة على محل{" "}
        <span className="font-semibold">{context.merchant.store_name}</span>.
      </p>
      <LogoutButton className="inline-block mt-6 text-primary font-semibold">
        تسجيل الخروج
      </LogoutButton>
    </AuthCard>
  );
}
