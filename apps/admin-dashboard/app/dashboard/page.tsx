import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export default async function DashboardOverviewPage() {
  const supabase = await createClient();

  const [
    { count: pendingMerchants },
    { count: pendingOrders },
    { count: activeMerchants },
    { count: totalOrders },
  ] = await Promise.all([
    supabase
      .from("merchants")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending"),
    supabase
      .from("orders")
      .select("id", { count: "exact", head: true })
      .eq("status", "ready_for_pickup"),
    supabase
      .from("merchants")
      .select("id", { count: "exact", head: true })
      .eq("status", "approved"),
    supabase.from("orders").select("id", { count: "exact", head: true }),
  ]);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">نظرة عامة</h1>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard
          label="محلات بانتظار الموافقة"
          value={pendingMerchants ?? 0}
          highlight={(pendingMerchants ?? 0) > 0}
        />
        <StatCard
          label="طلبات جاهزة للاستلام (تحتاج توصيل)"
          value={pendingOrders ?? 0}
          highlight={(pendingOrders ?? 0) > 0}
        />
        <StatCard label="محلات نشطة" value={activeMerchants ?? 0} />
        <StatCard label="إجمالي الطلبات" value={totalOrders ?? 0} />
      </div>

      <div className="flex gap-3 flex-wrap">
        {(pendingMerchants ?? 0) > 0 && (
          <Link
            href="/dashboard/merchants?status=pending"
            className="rounded-lg bg-primary text-white font-semibold px-5 py-3"
          >
            مراجعة المحلات الجديدة
          </Link>
        )}
        {(pendingOrders ?? 0) > 0 && (
          <Link
            href="/dashboard/orders?status=ready_for_pickup"
            className="rounded-lg border border-primary text-primary font-semibold px-5 py-3"
          >
            متابعة التوصيل
          </Link>
        )}
      </div>
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
