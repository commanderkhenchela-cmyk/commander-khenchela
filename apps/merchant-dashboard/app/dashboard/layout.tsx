import { redirect } from "next/navigation";
import { getMerchantContext } from "@/lib/merchant-context";
import LogoutButton from "@/components/logout-button";
import PushNotificationsSetup from "@/components/push-notifications-setup";
import { MerchantNav } from "@/components/merchant-nav";
import { LogOutIcon } from "@/components/ui/icons";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const context = await getMerchantContext();
  if (!context) redirect("/login");
  if (!context.merchant) redirect("/onboarding");
  if (context.merchant.status === "pending") redirect("/pending");
  if (context.merchant.status === "rejected") redirect("/rejected");

  return (
    <div className="flex flex-1 flex-col md:flex-row">
      <PushNotificationsSetup />
      <aside className="md:w-64 shrink-0 border-b md:border-b-0 md:border-l border-border bg-card">
        <div className="p-5 border-b border-border">
          <p className="font-bold text-lg">{context.merchant.store_name}</p>
          <p className="text-xs text-black/50 mt-0.5">لوحة تحكم التاجر</p>
        </div>
        <MerchantNav />
        <div className="p-3 mt-auto hidden md:block">
          <LogoutButton className="flex items-center gap-2.5 w-full text-right text-error text-sm px-3 py-2 rounded-lg hover:bg-error/5">
            <LogOutIcon className="h-5 w-5 shrink-0" />
            تسجيل الخروج
          </LogoutButton>
        </div>
      </aside>
      <main className="flex-1 p-4 md:p-8">{children}</main>
    </div>
  );
}
