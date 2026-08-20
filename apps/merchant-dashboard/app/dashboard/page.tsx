import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";

export default async function DashboardOverviewPage() {
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  const supabase = await createClient();

  const { count: pendingCount } = await supabase
    .from("orders")
    .select("id", { count: "exact", head: true })
    .eq("merchant_id", merchant.id)
    .eq("status", "pending");

  const { count: activeProductsCount } = await supabase
    .from("products")
    .select("id", { count: "exact", head: true })
    .eq("merchant_id", merchant.id)
    .eq("is_active", true);

  const { count: totalOrdersCount } = await supabase
    .from("orders")
    .select("id", { count: "exact", head: true })
    .eq("merchant_id", merchant.id);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">مرحبًا، {merchant.store_name}</h1>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <StatCard
          label="طلبات بانتظار موافقتك"
          value={pendingCount ?? 0}
          highlight={(pendingCount ?? 0) > 0}
        />
        <StatCard label="منتجات نشطة" value={activeProductsCount ?? 0} />
        <StatCard label="إجمالي الطلبات" value={totalOrdersCount ?? 0} />
      </div>

      {(pendingCount ?? 0) > 0 && (
        <Link
          href="/dashboard/orders?status=pending"
          className="inline-block rounded-lg bg-primary text-white font-semibold px-5 py-3"
        >
          مراجعة الطلبات الجديدة ({pendingCount})
        </Link>
      )}
    </div>
  );
}

function StatCard({
  label,
  value,
  highlight,
}: {
  label: string;
  value: number;
  highlight?: boolean;
}) {
  return (
    <div
      className={`rounded-2xl border p-5 ${
        highlight ? "border-primary bg-primary/5" : "border-border bg-card"
      }`}
    >
      <p className="text-3xl font-bold">{value}</p>
      <p className="text-sm text-black/60 mt-1">{label}</p>
    </div>
  );
}
