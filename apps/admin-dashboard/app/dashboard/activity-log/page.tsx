import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import { tableLabel, type ActivityLogEntry } from "@/lib/types";

const ACTION_COLORS: Record<string, string> = {
  إنشاء: "text-primary bg-primary/10",
  تعديل: "text-warning bg-warning/10",
  حذف: "text-error bg-error/10",
};

const ACTIONS = ["إنشاء", "تعديل", "حذف"];

// الجداول التي تكتب فعليًا في admin_activity_log اليوم (مطابقة لكل
// trigger موجود عبر الـ migrations) — وليست قائمة افتراضية مخمَّنة.
const TABLES = [
  "merchants",
  "drivers",
  "orders",
  "app_branding",
  "app_contact",
  "categories",
  "merchant_categories",
  "advertisements",
  "users",
  "home_sections",
  "services",
];

interface Filters {
  table?: string;
  action?: string;
  admin?: string;
  from?: string;
  to?: string;
}

export default async function ActivityLogPage({
  searchParams,
}: {
  searchParams: Promise<Filters>;
}) {
  const context = await getAdminContext();
  if (!context?.isSuperAdmin) redirect("/dashboard");

  const filters = await searchParams;

  const supabase = await createClient();
  let query = supabase
    .from("admin_activity_log")
    .select("id, admin_name, action, table_name, record_id, created_at")
    .order("created_at", { ascending: false })
    .limit(100);

  if (filters.table) query = query.eq("table_name", filters.table);
  if (filters.action) query = query.eq("action", filters.action);
  if (filters.admin) query = query.ilike("admin_name", `%${filters.admin}%`);
  if (filters.from) query = query.gte("created_at", filters.from);
  if (filters.to) query = query.lte("created_at", `${filters.to}T23:59:59`);

  const { data: logs } = await query;

  const items = (logs ?? []) as ActivityLogEntry[];

  const buildHref = (patch: Partial<Filters>) => {
    const next = { ...filters, ...patch };
    const params = new URLSearchParams();
    Object.entries(next).forEach(([k, v]) => {
      if (v) params.set(k, v);
    });
    const qs = params.toString();
    return `/dashboard/activity-log${qs ? `?${qs}` : ""}`;
  };

  const hasFilters = Boolean(
    filters.table || filters.action || filters.admin || filters.from || filters.to,
  );

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">سجل النشاطات</h1>
      <p className="text-sm text-black/60 mb-6">
        كل إجراء إداري مؤثر (الموافقة على محل، تعديل الهوية أو التصنيفات أو
        بيانات التواصل...) يُسجَّل هنا تلقائيًا من قاعدة البيانات نفسها —
        لا يمكن تعديل هذا السجل أو حذفه من أي واجهة. آخر 100 نتيجة مطابقة
        للفلاتر أدناه.
      </p>

      <form className="flex flex-wrap items-end gap-3 mb-4" method="GET">
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-black/60">اسم الأدمن</span>
          <input
            type="text"
            name="admin"
            defaultValue={filters.admin ?? ""}
            placeholder="بحث بالاسم"
            className="rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-black/60">من تاريخ</span>
          <input
            type="date"
            name="from"
            defaultValue={filters.from ?? ""}
            className="rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-black/60">إلى تاريخ</span>
          <input
            type="date"
            name="to"
            defaultValue={filters.to ?? ""}
            className="rounded-lg border border-border bg-card px-3 py-2 text-sm"
          />
        </label>
        {filters.table && <input type="hidden" name="table" value={filters.table} />}
        {filters.action && <input type="hidden" name="action" value={filters.action} />}
        <button
          type="submit"
          className="rounded-lg bg-primary text-white font-semibold px-4 py-2 text-sm"
        >
          بحث
        </button>
        {hasFilters && (
          <Link href="/dashboard/activity-log" className="text-sm text-black/50 underline">
            مسح كل الفلاتر
          </Link>
        )}
      </form>

      <div className="flex gap-2 mb-2 overflow-x-auto pb-1">
        <Link
          href={buildHref({ action: undefined })}
          className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-medium border ${
            !filters.action
              ? "bg-primary text-white border-primary"
              : "border-border text-black/70"
          }`}
        >
          كل الإجراءات
        </Link>
        {ACTIONS.map((a) => (
          <Link
            key={a}
            href={buildHref({ action: a })}
            className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-medium border ${
              filters.action === a
                ? "bg-primary text-white border-primary"
                : "border-border text-black/70"
            }`}
          >
            {a}
          </Link>
        ))}
      </div>

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        <Link
          href={buildHref({ table: undefined })}
          className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-medium border ${
            !filters.table
              ? "bg-primary text-white border-primary"
              : "border-border text-black/70"
          }`}
        >
          كل الأنواع
        </Link>
        {TABLES.map((t) => (
          <Link
            key={t}
            href={buildHref({ table: t })}
            className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-medium border ${
              filters.table === t
                ? "bg-primary text-white border-primary"
                : "border-border text-black/70"
            }`}
          >
            {tableLabel(t)}
          </Link>
        ))}
      </div>

      {items.length === 0 ? (
        <p className="text-black/60">
          {hasFilters
            ? "لا توجد نشاطات مطابقة لهذه الفلاتر."
            : "لا توجد نشاطات مسجَّلة بعد."}
        </p>
      ) : (
        <div className="grid gap-2">
          {items.map((log) => (
            <div
              key={log.id}
              className="rounded-xl border border-border bg-card p-4 flex items-center justify-between gap-4"
            >
              <div className="min-w-0">
                <p className="font-medium truncate">
                  {log.admin_name || "أدمن"}{" "}
                  <span className="text-black/60 font-normal">
                    {log.action} {tableLabel(log.table_name)}
                  </span>
                </p>
                <p className="text-xs text-black/40 mt-0.5">
                  {new Date(log.created_at).toLocaleString("ar-DZ")}
                </p>
              </div>
              <span
                className={`shrink-0 rounded-full px-3 py-1 text-xs font-semibold ${
                  ACTION_COLORS[log.action] ?? "text-black/60 bg-black/5"
                }`}
              >
                {log.action}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
