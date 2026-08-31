"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

interface NavModule {
  title: string;
  links: { href: string; label: string }[];
}

function isActive(href: string, pathname: string) {
  if (href === "/dashboard") return pathname === "/dashboard";
  return pathname === href || pathname.startsWith(`${href}/`);
}

/**
 * قائمة تنقّل قابلة للطيّ (Accordion) — بديل عن التبديل السابق بين وضع
 * عمودي (شاشات كبيرة) ووضع أفقي متراكب (شاشات ضيّقة، كان غير مرتّب
 * فعليًا مع نمو عدد الوحدات/الروابط هذه الجلسة). الآن: كل وحدة عنوان
 * قابل للضغط، وروابطها تظهر مباشرة تحته عموديًا عند فتحه — بنفس الشكل
 * على أي عرض شاشة، بلا أي منطق خاص بنقطة توقّف (breakpoint) للتنقّل
 * نفسه. الوحدة التي تحتوي الصفحة الحالية تُفتَح تلقائيًا عند التحميل.
 */
export default function SidebarNav({ modules }: { modules: NavModule[] }) {
  const pathname = usePathname();

  const [openTitles, setOpenTitles] = useState<Set<string>>(() => {
    const active = modules.find((m) =>
      m.links.some((l) => isActive(l.href, pathname)),
    );
    return new Set(active ? [active.title] : []);
  });

  function toggle(title: string) {
    setOpenTitles((prev) => {
      const next = new Set(prev);
      if (next.has(title)) {
        next.delete(title);
      } else {
        next.add(title);
      }
      return next;
    });
  }

  return (
    <nav className="flex flex-col p-3 gap-0.5">
      {modules.map((module) => {
        if (module.links.length === 0) return null;
        const isOpen = openTitles.has(module.title);

        return (
          <div key={module.title}>
            <button
              type="button"
              onClick={() => toggle(module.title)}
              className="w-full flex items-center justify-between gap-2 px-3 py-2 text-[11px] font-bold uppercase tracking-wide text-black/40 hover:text-black/60"
            >
              <span>{module.title}</span>
              <span
                className={`shrink-0 transition-transform ${isOpen ? "rotate-180" : ""}`}
              >
                ⌄
              </span>
            </button>
            {isOpen && (
              <div className="flex flex-col gap-0.5 mb-1">
                {module.links.map((link) => (
                  <NavLink
                    key={link.href}
                    href={link.href}
                    label={link.label}
                    active={isActive(link.href, pathname)}
                  />
                ))}
              </div>
            )}
          </div>
        );
      })}
    </nav>
  );
}

function NavLink({
  href,
  label,
  active,
}: {
  href: string;
  label: string;
  active: boolean;
}) {
  return (
    <Link
      href={href}
      className={`whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium hover:bg-primary/10 hover:text-primary ${
        active ? "bg-primary/10 text-primary" : ""
      }`}
    >
      {label}
    </Link>
  );
}
