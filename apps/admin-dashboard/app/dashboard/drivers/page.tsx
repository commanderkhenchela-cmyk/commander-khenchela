import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import type { Driver, DriverStatus } from "@/lib/types";

const FILTERS: { value: DriverStatus | "all"; label: string }[] = [
  { value: "pending", label: "بانتظار الموافقة" },
  { value: "approved", label: "موافَق عليهم" },
  { value: "rejected", label: "مرفوضون" },
  { value: "all", label: "الكل" },
];

const STATUS_LABELS: Record<DriverStatus, string> = {
  pending: "بانتظار الموافقة",
  approved: "موافَق عليه",
  rejected: "مرفوض",
};

export default async function DriversPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { status } = await searchParams;
  const activeFilter = status ?? "pending";

  const supabase = await createClient();
  let query = supabase
    .from("drivers")
    .select("id, full_name, phone, vehicle_type, status, is_online, created_at")
    .order("created_at", { ascending: false });

  if (activeFilter !== "all") {
    query = query.eq("status", activeFilter);
  }

  const { data: drivers } = await query;
  const items = (drivers ?? []) as Driver[];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">الموصّلون</h1>

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        {FILTERS.map((f) => (
          <Link
            key={f.value}
            href={`/dashboard/drivers?status=${f.value}`}
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
        <p className="text-black/60">لا يوجد موصّلون في هذا التصنيف.</p>
      ) : (
        <div className="grid gap-3">
          {items.map((d) => (
            <Link
              key={d.id}
              href={`/dashboard/drivers/${d.id}`}
              className="rounded-xl border border-border bg-card p-4 flex items-center gap-4"
            >
              <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center shrink-0 text-lg">
                🏍️
              </div>
              <div className="min-w-0 flex-1">
                <p className="font-semibold truncate">{d.full_name}</p>
                <p className="text-sm text-black/60 truncate">{d.phone}</p>
              </div>
              {d.is_online && (
                <span className="shrink-0 rounded-full px-3 py-1 text-xs font-semibold text-primary bg-primary/10">
                  متصل الآن
                </span>
              )}
              <span className="shrink-0 rounded-full px-3 py-1 text-xs font-semibold text-warning bg-warning/10">
                {STATUS_LABELS[d.status]}
              </span>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
