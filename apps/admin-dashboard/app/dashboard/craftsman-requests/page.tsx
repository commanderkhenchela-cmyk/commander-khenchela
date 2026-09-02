import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type {
  CraftsmanRequest,
  CraftsmanRequestStatus,
} from "@/lib/types";
import { CRAFT_TYPE_LABELS, CRAFTSMAN_REQUEST_STATUS_LABELS } from "@/lib/types";

const FILTERS: { value: CraftsmanRequestStatus | "all"; label: string }[] = [
  { value: "pending", label: "قيد المراجعة" },
  { value: "assigned", label: "تم الربط" },
  { value: "completed", label: "مكتملة" },
  { value: "cancelled", label: "ملغاة" },
  { value: "all", label: "الكل" },
];

/**
 * قائمة طلبات "حرفيون" — نفس هيكل drivers/page.tsx (تبويبات حالة +
 * بطاقات). محروسة بنفس capability المستخدَمة لصفحة الطلبات
 * (order.view) — طلبات حرفيين قائمة انتظار يديرها نفس فريق العمليات،
 * لا حاجة لـ capability منفصلة لميزة V1 يدوية بالكامل.
 */
export default async function CraftsmanRequestsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.hasCapability("order.view")) redirect("/dashboard");

  const { status } = await searchParams;
  const activeFilter = status ?? "pending";

  const supabase = await createClient();
  let query = supabase
    .from("craftsman_requests")
    .select(
      "id, craft_type, description, status, assigned_craftsman_name, created_at, users(full_name, phone)",
    )
    .order("created_at", { ascending: false });

  if (activeFilter !== "all") {
    query = query.eq("status", activeFilter);
  }

  const { data: requests } = await query;
  const items = (requests ?? []) as unknown as CraftsmanRequest[];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">طلبات الحرفيين</h1>

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        {FILTERS.map((f) => (
          <Link
            key={f.value}
            href={`/dashboard/craftsman-requests?status=${f.value}`}
            className={`whitespace-nowrap rounded-full px-4 py-2 text-sm font-medium border ${
              activeFilter === f.value
                ? "bg-primary text-white border-primary"
                : "border-border text-black/70"
            }`}
          >
            {f.label}
          </Link>
        ))}
      </div>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد طلبات فـ هذا التصنيف.</p>
      ) : (
        <div className="grid gap-3">
          {items.map((r) => (
            <Link
              key={r.id}
              href={`/dashboard/craftsman-requests/${r.id}`}
              className="rounded-xl border border-border bg-card p-4 flex items-center gap-4"
            >
              <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center shrink-0 text-lg">
                🛠️
              </div>
              <div className="min-w-0 flex-1">
                <p className="font-semibold truncate">
                  {CRAFT_TYPE_LABELS[r.craft_type]} — {r.users?.full_name ?? "؟"}
                </p>
                <p className="text-sm text-black/60 truncate">
                  {r.description}
                </p>
              </div>
              <StatusBadge status={r.status} />
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

/// نفس نمط StatusBadge فـ orders/page.tsx — لون يتبع الحالة الفعلية
/// بدل لون واحد ثابت (warning) لكل الحالات.
function StatusBadge({ status }: { status: CraftsmanRequestStatus }) {
  const colorClass =
    status === "completed"
      ? "text-primary bg-primary/10"
      : status === "cancelled"
        ? "text-error bg-error/10"
        : "text-warning bg-warning/10";

  return (
    <span
      className={`shrink-0 rounded-full px-3 py-1 text-xs font-semibold ${colorClass}`}
    >
      {CRAFTSMAN_REQUEST_STATUS_LABELS[status]}
    </span>
  );
}
