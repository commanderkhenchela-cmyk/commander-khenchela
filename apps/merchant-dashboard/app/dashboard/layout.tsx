import { redirect } from "next/navigation";
import Link from "next/link";
import { getMerchantContext } from "@/lib/merchant-context";
import LogoutButton from "@/components/logout-button";

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
      <aside className="md:w-64 shrink-0 border-b md:border-b-0 md:border-l border-border bg-card">
        <div className="p-5 border-b border-border">
          <p className="font-bold text-lg">{context.merchant.store_name}</p>
          <p className="text-xs text-black/50 mt-0.5">لوحة تحكم التاجر</p>
        </div>
        <nav className="flex md:flex-col p-3 gap-1 overflow-x-auto">
          <NavLink href="/dashboard" label="نظرة عامة" />
          <NavLink href="/dashboard/orders" label="الطلبات" />
          <NavLink href="/dashboard/products" label="المنتجات" />
          <NavLink href="/dashboard/hours" label="ساعات العمل" />
          <NavLink href="/dashboard/notifications" label="🔔 الإشعارات" />
          <NavLink href="/dashboard/settings" label="إعدادات المحل" />
        </nav>
        <div className="p-3 mt-auto hidden md:block">
          <LogoutButton className="w-full text-right text-error text-sm px-3 py-2" />
        </div>
      </aside>
      <main className="flex-1 p-4 md:p-8">{children}</main>
    </div>
  );
}

function NavLink({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium hover:bg-primary/10 hover:text-primary"
    >
      {label}
    </Link>
  );
}
