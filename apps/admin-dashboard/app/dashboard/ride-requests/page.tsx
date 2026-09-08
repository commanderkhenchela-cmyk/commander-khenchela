import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { RideRequest, RideRequestStatus } from "@/lib/types";
import { RIDE_REQUEST_STATUS_LABELS } from "@/lib/types";

const PAGE_SIZE = 20;

const FILTERS: { value: RideRequestStatus | "all"; label: string }[] = [
  { value: "pending", label: "قيد الانتظار" },
  { value: "accepted", label: "مقبولة" },
  { value: "in_progress", label: "جارية الآن" },
  { value: "completed", label: "مكتملة" },
  { value: "cancelled", label: "ملغاة" },
  { value: "all", label: "الكل" },
];

/**
 * قائمة طلبات "الطاكسي" (Taxi) — كانت غائبة كليًا عن الإدارة رغم أن
 * RLS الإدارية (ride_requests_select_admin) جاهزة منذ migration
 * الإنشاء الأصلية. نفس هيكل delivery-requests/page.tsx بالحرف، بإضافة
 * ترقيم صفحي حقيقي (server-side .range) لأن رحلات Taxi اليومية
 * متوقَّع أن تكون أكثر عددًا من طلبات الحرفيين على المدى المتوسط.
 */
export default async function RideRequestsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; page?: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.hasCapability("order.view")) redirect("/dashboard");

  const { status, page: pageParam } = await searchParams;
  const activeFilter = status ?? "pending";
  const page = Math.max(1, Number(pageParam ?? "1") || 1);
  const from = (page - 1) * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  const supabase = await createClient();
  let query = supabase
    .from("ride_requests")
    .select(
      "id, status, fare, created_at, users(full_name, phone), " +
        "pickup_address:addresses!pickup_address_id(address_text, communes(name)), " +
        "dropoff_address:addresses!dropoff_address_id(address_text, communes(name))",
      { count: "exact" },
    )
    .order("created_at", { ascending: false })
    .range(from, to);

  if (activeFilter !== "all") {
    query = query.eq("status", activeFilter);
  }

  const { data: requests, count } = await query;
  const items = (requests ?? []) as unknown as RideRequest[];
  const totalPages = count ? Math.max(1, Math.ceil(count / PAGE_SIZE)) : 1;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">الطاكسي (Taxi)</h1>

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        {FILTERS.map((f) => (
          <Link
            key={f.value}
            href={`/dashboard/ride-requests?status=${f.value}`}
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
        <p className="text-black/60">لا توجد رحلات فـ هذا التصنيف.</p>
      ) : (
        <>
          <div className="grid gap-3">
            {items.map((r) => (
              <Link
                key={r.id}
                href={`/dashboard/ride-requests/${r.id}`}
                className="rounded-xl border border-border bg-card p-4 flex items-center gap-4"
              >
                <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center shrink-0 text-lg">
                  🚕
                </div>
                <div className="min-w-0 flex-1">
                  <p className="font-semibold truncate">
                    {r.users?.full_name ?? "؟"}
                  </p>
                  <p className="text-sm text-black/60 truncate">
                    {r.pickup_address?.communes?.name ?? "؟"} ←{" "}
                    {r.dropoff_address?.communes?.name ?? "؟"}
                  </p>
                </div>
                <StatusBadge status={r.status} />
              </Link>
            ))}
          </div>

          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2 mt-6">
              <Link
                href={`/dashboard/ride-requests?status=${activeFilter}&page=${page - 1}`}
                aria-disabled={page <= 1}
                className={`rounded-lg border border-border px-3 py-1.5 text-sm ${
                  page <= 1 ? "pointer-events-none opacity-40" : ""
                }`}
              >
                السابق
              </Link>
              <span className="text-sm text-black/60">
                صفحة {page} من {totalPages}
              </span>
              <Link
                href={`/dashboard/ride-requests?status=${activeFilter}&page=${page + 1}`}
                aria-disabled={page >= totalPages}
                className={`rounded-lg border border-border px-3 py-1.5 text-sm ${
                  page >= totalPages ? "pointer-events-none opacity-40" : ""
                }`}
              >
                التالي
              </Link>
            </div>
          )}
        </>
      )}
    </div>
  );
}

/// نفس نمط StatusBadge فـ delivery-requests/page.tsx.
function StatusBadge({ status }: { status: RideRequestStatus }) {
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
      {RIDE_REQUEST_STATUS_LABELS[status]}
    </span>
  );
}
