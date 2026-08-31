import { redirect } from "next/navigation";
import { getMerchantContext } from "@/lib/merchant-context";
import LogoutButton from "@/components/logout-button";
import { AuthCard } from "@/components/ui/auth-card";
import { XCircleIcon } from "@/components/ui/icons";

export default async function RejectedPage() {
  const context = await getMerchantContext();
  if (!context) redirect("/login");
  if (!context.merchant) redirect("/onboarding");
  if (context.merchant.status !== "rejected") redirect("/");

  return (
    <AuthCard className="text-center">
      <XCircleIcon className="h-12 w-12 mx-auto mb-4 text-error" />
      <h1 className="text-xl font-bold mb-2">لم تتم الموافقة على المحل</h1>
      <p className="text-black/70">
        للأسف لم يوافَق على محل{" "}
        <span className="font-semibold">{context.merchant.store_name}</span>{" "}
        حاليًا. للاستفسار تواصل مع الإدارة.
      </p>
      <LogoutButton className="inline-block mt-6 text-primary font-semibold">
        تسجيل الخروج
      </LogoutButton>
    </AuthCard>
  );
}
