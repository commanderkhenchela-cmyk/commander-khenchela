"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { AppNotification } from "@/lib/types";

// مسار كل نوع كيان — امتداد بسيط بلا شاشة جديدة، يعيد استخدام صفحات
// التفاصيل الموجودة أصلًا (merchants/[id]، drivers/[id]، orders/[id]).
const ENTITY_ROUTES: Record<string, string> = {
  merchant: "/dashboard/merchants",
  driver: "/dashboard/drivers",
  order: "/dashboard/orders",
};

/**
 * قائمة الإشعارات — جزء تفاعلي (تعليم كمقروء + استماع لحظي)، منفصل عن
 * page.tsx حتى يبقى ذاك Server Component بسيط. الاستعلام بدون أي فلتر
 * user_id يدوي: RLS (notifications_select_own) تحصر النتائج تلقائيًا
 * على صاحب الجلسة الحالية (كل إداري يرى إشعاراته هو فقط)، ونفس الشيء
 * لتغييرات postgres_changes.
 */
export default function NotificationsList() {
  const router = useRouter();
  const [notifications, setNotifications] = useState<
    AppNotification[] | null
  >(null);

  useEffect(() => {
    let ignore = false;
    const supabase = createClient();

    async function load() {
      const { data } = await supabase
        .from("notifications")
        .select("id, title, body, type, is_read, created_at, entity_type, entity_id")
        .order("created_at", { ascending: false });
      if (!ignore) {
        setNotifications((data ?? []) as AppNotification[]);
      }
    }

    load();

    const channel = supabase
      .channel("admin-notifications")
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "notifications" },
        () => load(),
      )
      .subscribe();

    return () => {
      ignore = true;
      supabase.removeChannel(channel);
    };
  }, []);

  async function markAsRead(n: AppNotification) {
    if (n.is_read) return;

    const supabase = createClient();
    await supabase
      .from("notifications")
      .update({ is_read: true })
      .eq("id", n.id);

    setNotifications((prev) =>
      prev ? prev.map((x) => (x.id === n.id ? { ...x, is_read: true } : x)) : prev,
    );
  }

  // نفس منطق العميل: تعليم كمقروء دائمًا، ثم تنقّل فقط إن وُجد كيان
  // مرتبط بمسار معروف — إشعارات قديمة/عامة (entity_type=null) تبقى
  // بلا تنقّل كما كانت تمامًا.
  function handleClick(n: AppNotification) {
    markAsRead(n);
    if (n.entity_type && n.entity_id && ENTITY_ROUTES[n.entity_type]) {
      router.push(`${ENTITY_ROUTES[n.entity_type]}/${n.entity_id}`);
    }
  }

  if (notifications === null) {
    return <p className="text-black/60">جارِ التحميل...</p>;
  }

  if (notifications.length === 0) {
    return <p className="text-black/60">لا توجد إشعارات بعد.</p>;
  }

  const unreadCount = notifications.filter((n) => !n.is_read).length;

  return (
    <div>
      {unreadCount > 0 && (
        <p className="text-sm text-primary font-medium mb-3">
          {unreadCount} إشعار غير مقروء
        </p>
      )}
      <div className="grid gap-3">
        {notifications.map((n) => (
          <button
            key={n.id}
            onClick={() => handleClick(n)}
            className={`text-right rounded-xl border p-4 ${
              n.is_read
                ? "border-border bg-card"
                : "border-primary/30 bg-primary/5"
            }`}
          >
            <div className="flex items-center justify-between gap-2">
              <p
                className={`font-semibold ${n.is_read ? "" : "text-primary"}`}
              >
                {n.title}
              </p>
              <span className="shrink-0 text-xs text-black/40">
                {new Date(n.created_at).toLocaleString("ar-DZ")}
              </span>
            </div>
            <p className="text-sm text-black/60 mt-1">{n.body}</p>
          </button>
        ))}
      </div>
    </div>
  );
}
