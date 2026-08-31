import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";
import { StatCard } from "@/components/ui/stat-card";
import { Button } from "@/components/ui/button";

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
        <Button href="/dashboard/orders?status=pending">
          مراجعة الطلبات الجديدة ({pendingCount})
        </Button>
      )}
    </div>
  );
}
