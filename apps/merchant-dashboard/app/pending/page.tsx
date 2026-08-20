import { redirect } from "next/navigation";
import { getMerchantContext } from "@/lib/merchant-context";
import LogoutButton from "@/components/logout-button";

export default async function PendingPage() {
  const context = await getMerchantContext();
  if (!context) redirect("/login");
  if (!context.merchant) redirect("/onboarding");
  if (context.merchant.status !== "pending") redirect("/");

  return (
    <main className="flex flex-1 items-center justify-center p-6">
      <div className="w-full max-w-sm rounded-2xl bg-card border border-border p-8 shadow-sm text-center">
        <div className="text-5xl mb-4">⏳</div>
        <h1 className="text-xl font-bold mb-2">محلك قيد المراجعة</h1>
        <p className="text-black/70">
          أرسلنا طلبك لفريق الإدارة. سنُعلمك فور الموافقة على محل{" "}
          <span className="font-semibold">{context.merchant.store_name}</span>
          .
        </p>
        <LogoutButton className="inline-block mt-6 text-primary font-semibold" />
      </div>
    </main>
  );
}
