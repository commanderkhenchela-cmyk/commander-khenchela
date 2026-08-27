import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
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

  const modules = buildNavModules(context);

  const supabase = await createClient();
  const { data: branding } = await supabase
    .from("app_branding")
    .select("logo_url")
    .eq("id", "default")
    .maybeSingle();

  return (
    <div className="flex flex-1 flex-col md:flex-row">
      <aside className="md:w-64 shrink-0 border-b md:border-b-0 md:border-l border-border bg-card">
        <div className="p-5 border-b border-border">
          <div className="flex items-center gap-3">
            {branding?.logo_url && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={branding.logo_url}
                alt=""
                className="w-9 h-9 rounded-lg object-cover shrink-0"
              />
            )}
            <div className="min-w-0">
              <p className="font-bold text-lg leading-tight">COMMANDER KHENCHELA</p>
              <p className="text-[11px] text-primary font-medium">
                خنشلة بين يديك — مركز التحكّم
              </p>
            </div>
          </div>
          <p className="text-xs text-black/50 mt-2">
            {context.fullName || "مرحبًا"}
          </p>
          <p className="text-xs text-primary font-medium mt-1">
            {context.role ? ROLE_LABELS[context.role] : ""}
          </p>
        </div>
        <nav className="flex md:flex-col p-3 gap-1 overflow-x-auto">
          {modules.map((module) =>
            module.links.length === 0 ? null : (
              <div key={module.title} className="md:mb-2">
                <p className="hidden md:block px-3 pt-2 pb-1 text-[11px] font-bold uppercase tracking-wide text-black/40">
                  {module.title}
                </p>
                {module.links.map((link) => (
                  <NavLink key={link.href} href={link.href} label={link.label} />
                ))}
              </div>
            ),
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

interface NavModule {
  title: string;
  links: { href: string; label: string }[];
}

/**
 * قائمة التنقّل مبنية من بيانات (Module → Links) بدل شروط JSX متكرّرة
 * كما كانت سابقًا — نفس الروابط بالضبط، بلا حذف أو إضافة صفحة واحدة،
 * فقط مُجمَّعة في Modules واضحة ومحروسة بـ Capabilities الحقيقية
 * (مقروءة من role_capabilities عبر context.hasCapability) بدل Booleans
 * منفصلة القراءة لكل رابط. الروابط التي لم تُمنَح Capability صريحة بعد
 * (الفريق/الهوية/سجل النشاطات/بيانات التواصل) تبقى محروسة بـ
 * isSuperAdmin تمامًا كما كانت — لا تغيير سلوك هناك.
 */
function buildNavModules(context: Awaited<ReturnType<typeof getAdminContext>>): NavModule[] {
  if (!context) return [];

  return [
    {
      title: "نظرة عامة",
      links: [
        { href: "/dashboard", label: "نظرة عامة" },
        { href: "/dashboard/notifications", label: "🔔 الإشعارات" },
      ],
    },
    {
      title: "المحلات والموصّلون",
      links: context.hasCapability("merchant.view")
        ? [
            { href: "/dashboard/merchants", label: "المحلات" },
            { href: "/dashboard/drivers", label: "الموصّلون" },
            { href: "/dashboard/categories", label: "التصنيفات" },
            { href: "/dashboard/merchant-categories", label: "تصنيفات المحلات" },
            { href: "/dashboard/home-sections", label: "أقسام الصفحة الرئيسية" },
            { href: "/dashboard/services", label: "الخدمات" },
          ]
        : [],
    },
    {
      title: "الطلبات",
      links: context.hasCapability("order.view")
        ? [{ href: "/dashboard/orders", label: "الطلبات" }]
        : [],
    },
    {
      title: "الإعلانات",
      links: context.hasCapability("advertisement.view")
        ? [{ href: "/dashboard/advertisements", label: "لوحة إعلانات الفيديو" }]
        : [],
    },
    {
      title: "الإدارة والإعدادات",
      links: context.isSuperAdmin
        ? [
            { href: "/dashboard/settings", label: "إعدادات المنصة" },
            { href: "/dashboard/branding", label: "الهوية والشعار" },
            { href: "/dashboard/app-settings", label: "بيانات التواصل" },
            { href: "/dashboard/activity-log", label: "سجل النشاطات" },
            { href: "/dashboard/team", label: "فريق الإدارة" },
          ]
        : [],
    },
  ];
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
