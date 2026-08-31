"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ComponentType, SVGProps } from "react";

interface NavLink {
  href: string;
  label: string;
  icon: ComponentType<SVGProps<SVGSVGElement>>;
}

/** نفس روابط dashboard/layout.tsx بالضبط (7 روابط، بلا مجموعات — الشريط
 * هنا لا يحتاج Accordion كما في admin-dashboard لأنه مسطّح أصلًا وأكّد
 * المستخدم أنه يبدو مرتّبًا). الإضافة الوحيدة: تمييز الرابط النشط عبر
 * usePathname (لم يكن موجودًا إطلاقًا سابقًا في هذا التطبيق) + أيقونة
 * بدل emoji. لذلك هذا الجزء وحده Client Component، بقية layout.tsx يبقى
 * Server Component كما هو. */
export function MerchantNav({ links }: { links: NavLink[] }) {
  const pathname = usePathname();

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
