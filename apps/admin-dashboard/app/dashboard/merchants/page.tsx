import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import type { Merchant, MerchantStatus } from "@/lib/types";

const FILTERS: { value: MerchantStatus | "all"; label: string }[] = [
  { value: "pending", label: "بانتظار الموافقة" },
  { value: "approved", label: "موافَق عليها" },
  { value: "rejected", label: "مرفوضة" },
  { value: "all", label: "الكل" },
];

const STATUS_LABELS: Record<MerchantStatus, string> = {
  pending: "بانتظار الموافقة",
  approved: "موافَق عليه",
  rejected: "مرفوض",
};

export default async function MerchantsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { status } = await searchParams;
  const activeFilter = status ?? "pending";

  const supabase = await createClient();
  let query = supabase
    .from("merchants")
    .select(
      "id, owner_user_id, store_name, wilaya_id, commune_id, address_text, phone, status, created_at, communes(name)",
    )
    .order("created_at", { ascending: false });

  if (activeFilter !== "all") {
    query = query.eq("status", activeFilter);
  }

  const { data: merchants } = await query;
  const items = (merchants ?? []) as unknown as Merchant[];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">المحلات</h1>

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        {FILTERS.map((f) => (
          <Link
            key={f.value}
            href={`/dashboard/merchants?status=${f.value}`}
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
        <p className="text-black/60">لا توجد محلات في هذا التصنيف.</p>
      ) : (
        <div className="grid gap-3">
          {items.map((m) => (
            <Link
              key={m.id}
              href={`/dashboard/merchants/${m.id}`}
              className="rounded-xl border border-border bg-card p-4 flex items-center justify-between gap-4"
            >
              <div className="min-w-0">
                <p className="font-semibold truncate">{m.store_name}</p>
                <p className="text-sm text-black/60 truncate">
                  {m.communes?.name} — {m.phone}
                </p>
              </div>
              <span className="shrink-0 rounded-full px-3 py-1 text-xs font-semibold text-warning bg-warning/10">
                {STATUS_LABELS[m.status]}
              </span>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
