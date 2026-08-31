import { redirect } from "next/navigation";
import Image from "next/image";
import { getMerchantContext } from "@/lib/merchant-context";
import LogoutButton from "@/components/logout-button";
import PushNotificationsSetup from "@/components/push-notifications-setup";
import { MerchantNav } from "@/components/merchant-nav";
import { StoreStatusToggle } from "@/components/store-status-toggle";
import { LogOutIcon, PictureIcon } from "@/components/ui/icons";

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
        <div className="p-5 border-b border-border flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg overflow-hidden border border-border bg-background shrink-0 relative flex items-center justify-center">
            {context.merchant.logo_url ? (
              <Image
                src={context.merchant.logo_url}
                alt={`شعار محل ${context.merchant.store_name}`}
                fill
                unoptimized
                className="object-cover"
              />
            ) : (
              <PictureIcon className="h-5 w-5 text-black/25" />
            )}
          </div>
          <div className="min-w-0">
            <p className="font-bold text-lg truncate">{context.merchant.store_name}</p>
            <p className="text-xs text-black/50 mt-0.5">لوحة تحكم التاجر</p>
          </div>
        </div>
        <div className="p-3 border-b border-border">
          <StoreStatusToggle
            merchantId={context.merchant.id}
            initialIsOpen={context.merchant.is_open}
          />
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
