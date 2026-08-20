import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { ORDER_STATUS_LABELS, type AdminOrder, type OrderStatus } from "@/lib/types";

const FILTERS: { value: OrderStatus | "all"; label: string }[] = [
  { value: "all", label: "الكل" },
  { value: "pending", label: "بانتظار التاجر" },
  { value: "confirmed", label: "مؤكَّدة" },
  { value: "preparing", label: "قيد التجهيز" },
  { value: "ready_for_pickup", label: "جاهزة للاستلام" },
  { value: "picked_up", label: "مستلَمة" },
  { value: "out_for_delivery", label: "في التوصيل" },
  { value: "delivered", label: "تم التسليم" },
];

export default async function OrdersPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { status } = await searchParams;
  const supabase = await createClient();

  let query = supabase
    .from("orders")
    .select(
      "id, status, subtotal, delivery_fee, total_amount, merchant_amount, platform_commission_amount, created_at, merchants(store_name, phone), addresses(address_text, phone, communes(name))",
    )
    .order("created_at", { ascending: false });

  if (status && status !== "all") {
    query = query.eq("status", status);
  }

  const { data: orders } = await query;
  const items = (orders ?? []) as unknown as AdminOrder[];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">الطلبات</h1>

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        {FILTERS.map((f) => (
          <Link
            key={f.value}
            href={f.value === "all" ? "/dashboard/orders" : `/dashboard/orders?status=${f.value}`}
            className={`whitespace-nowrap rounded-full px-4 py-2 text-sm font-medium border ${
              (status ?? "all") === f.value
                ? "bg-primary text-white border-primary"
                : "border-border text-black/70"
            }`}
          >
            {f.label}
          </Link>
        ))}
      </div>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد طلبات في هذا التصنيف.</p>
      ) : (
        <div className="grid gap-3">
          {items.map((order) => (
            <Link
              key={order.id}
              href={`/dashboard/orders/${order.id}`}
              className="rounded-xl border border-border bg-card p-4 flex items-center justify-between gap-4"
            >
              <div className="min-w-0">
                <p className="font-semibold truncate">
                  {order.merchants?.store_name}
                </p>
                <p className="text-sm text-black/60 truncate">
                  {order.addresses?.communes?.name} —{" "}
                  {order.addresses?.address_text}
                </p>
              </div>
              <div className="text-left shrink-0">
                <p className="font-bold">{order.total_amount.toFixed(0)} دج</p>
                <StatusBadge status={order.status} />
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: OrderStatus }) {
  const colorClass =
    status === "delivered"
      ? "text-primary bg-primary/10"
      : status === "cancelled" || status === "rejected"
        ? "text-error bg-error/10"
        : "text-warning bg-warning/10";

  return (
    <span className={`inline-block mt-1 rounded-full px-3 py-1 text-xs font-semibold ${colorClass}`}>
      {ORDER_STATUS_LABELS[status]}
    </span>
  );
}
