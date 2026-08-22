import { redirect } from "next/navigation";
import Link from "next/link";
import { getAdminContext } from "@/lib/admin-context";
import LogoutButton from "@/components/logout-button";

const ROLE_LABELS: Record<string, string> = {
  admin: "مدير عام (صلاحية كاملة)",
  manager: "مدير",
  ads_manager: "مدير الإعلانات",
};

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const context = await getAdminContext();
  if (!context) redirect("/login");
  if (!context.isAdmin) redirect("/");

  return (
    <div className="flex flex-1 flex-col md:flex-row">
      <aside className="md:w-64 shrink-0 border-b md:border-b-0 md:border-l border-border bg-card">
        <div className="p-5 border-b border-border">
          <p className="font-bold text-lg">لوحة الإدارة</p>
          <p className="text-xs text-black/50 mt-0.5">
            {context.fullName || "مرحبًا"}
          </p>
          <p className="text-xs text-primary font-medium mt-1">
            {context.role ? ROLE_LABELS[context.role] : ""}
          </p>
        </div>
        <nav className="flex md:flex-col p-3 gap-1 overflow-x-auto">
          <NavLink href="/dashboard" label="نظرة عامة" />
          <NavLink href="/dashboard/notifications" label="🔔 الإشعارات" />

          {context.canManageStores && (
            <>
              <NavLink href="/dashboard/merchants" label="المحلات" />
              <NavLink href="/dashboard/categories" label="التصنيفات" />
              <NavLink
                href="/dashboard/merchant-categories"
                label="تصنيفات المحلات"
              />
              <NavLink
                href="/dashboard/home-sections"
                label="أقسام الصفحة الرئيسية"
              />
            </>
          )}

          {context.isSuperAdmin && (
            <NavLink href="/dashboard/orders" label="الطلبات" />
          )}

          {context.canManageAds && (
            <NavLink
              href="/dashboard/advertisements"
              label="لوحة إعلانات الفيديو"
            />
          )}

          {context.isSuperAdmin && (
            <>
              <NavLink href="/dashboard/settings" label="إعدادات المنصة" />
              <NavLink href="/dashboard/branding" label="الهوية والشعار" />
              <NavLink href="/dashboard/app-settings" label="بيانات التواصل" />
              <NavLink href="/dashboard/activity-log" label="سجل النشاطات" />
              <NavLink href="/dashboard/team" label="فريق الإدارة" />
            </>
          )}
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
