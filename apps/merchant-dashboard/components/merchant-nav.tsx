"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BellIcon,
  ClipboardListIcon,
  ClockIcon,
  HomeIcon,
  PackageIcon,
  SettingsIcon,
  WalletIcon,
} from "@/components/ui/icons";

/** نفس روابط dashboard/layout.tsx القديم بالضبط (7 روابط، بلا مجموعات —
 * الشريط هنا لا يحتاج Accordion كما في admin-dashboard لأنه مسطّح أصلًا
 * وأكّد المستخدم أنه يبدو مرتّبًا). مُعرَّفة هنا داخل الـClient Component
 * نفسه (وليست prop قادمة من layout.tsx) لأن مراجع مكوّنات React
 * (الأيقونات) لا يمكن تمريرها كـ prop عادي من Server Component إلى
 * Client Component — يسبّب خطأ serialization وقت التنفيذ رغم نجاح
 * npm run build (لا يُنفَّذ فعليًا أثناء البناء لمسار ديناميكي). */
const NAV_LINKS = [
  { href: "/dashboard", label: "نظرة عامة", icon: HomeIcon },
  { href: "/dashboard/orders", label: "الطلبات", icon: ClipboardListIcon },
  { href: "/dashboard/products", label: "المنتجات", icon: PackageIcon },
  { href: "/dashboard/hours", label: "ساعات العمل", icon: ClockIcon },
  { href: "/dashboard/wallet", label: "محفظتي", icon: WalletIcon },
  { href: "/dashboard/notifications", label: "الإشعارات", icon: BellIcon },
  { href: "/dashboard/settings", label: "إعدادات المحل", icon: SettingsIcon },
];

export function MerchantNav() {
  const pathname = usePathname();
  const links = NAV_LINKS;

  function isActive(href: string) {
    if (href === "/dashboard") return pathname === "/dashboard";
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  return (
    <nav className="flex md:flex-col p-3 gap-1 overflow-x-auto">
      {links.map((link) => {
        const active = isActive(link.href);
        const Icon = link.icon;
        return (
          <Link
            key={link.href}
            href={link.href}
            className={`flex items-center gap-2.5 whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium hover:bg-primary/10 hover:text-primary ${
              active ? "bg-primary/10 text-primary" : ""
            }`}
          >
            <Icon className="h-5 w-5 shrink-0" />
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
