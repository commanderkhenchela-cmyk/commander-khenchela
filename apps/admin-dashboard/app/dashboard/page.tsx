import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import { tableLabel, type ActivityLogEntry } from "@/lib/types";

export default async function DashboardOverviewPage() {
  const context = await getAdminContext();
  const supabase = await createClient();

  const [
    { count: pendingMerchants },
    { count: pendingOrders },
    { count: activeMerchants },
    { count: totalOrders },
    { data: recentActivity },
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
    supabase
      .from("admin_activity_log")
      .select("id, admin_name, action, table_name, record_id, created_at")
      .order("created_at", { ascending: false })
      .limit(5),
  ]);

  const activity = (recentActivity ?? []) as ActivityLogEntry[];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">نظرة عامة</h1>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {context?.canManageStores && (
          <>
            <StatCard
              label="محلات بانتظار الموافقة"
              value={pendingMerchants ?? 0}
              highlight={(pendingMerchants ?? 0) > 0}
            />
            <StatCard label="محلات نشطة" value={activeMerchants ?? 0} />
          </>
        )}
        {context?.isSuperAdmin && (
          <>
            <StatCard
              label="طلبات جاهزة للاستلام (تحتاج توصيل)"
              value={pendingOrders ?? 0}
              highlight={(pendingOrders ?? 0) > 0}
            />
            <StatCard label="إجمالي الطلبات" value={totalOrders ?? 0} />
          </>
        )}
      </div>

      <div className="flex gap-3 flex-wrap">
        {context?.canManageStores && (pendingMerchants ?? 0) > 0 && (
          <Link
            href="/dashboard/merchants?status=pending"
            className="rounded-lg bg-primary text-white font-semibold px-5 py-3"
          >
            مراجعة المحلات الجديدة
          </Link>
        )}
        {context?.isSuperAdmin && (pendingOrders ?? 0) > 0 && (
          <Link
            href="/dashboard/orders?status=ready_for_pickup"
            className="rounded-lg border border-primary text-primary font-semibold px-5 py-3"
          >
            متابعة التوصيل
          </Link>
        )}
      </div>

      {context?.isSuperAdmin && (
      <div className="mt-8">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-lg font-bold">آخر النشاطات</h2>
          <Link
            href="/dashboard/activity-log"
            className="text-sm text-primary font-medium"
          >
            عرض الكل
          </Link>
        </div>
        {activity.length === 0 ? (
          <p className="text-sm text-black/50">لا توجد نشاطات بعد.</p>
        ) : (
          <div className="grid gap-2">
            {activity.map((log) => (
              <div
                key={log.id}
                className="rounded-lg border border-border bg-card px-4 py-2.5 flex items-center justify-between text-sm"
              >
                <span>
                  <span className="font-medium">
                    {log.admin_name || "أدمن"}
                  </span>{" "}
                  <span className="text-black/60">
                    {log.action} {tableLabel(log.table_name)}
                  </span>
                </span>
                <span className="text-xs text-black/40 shrink-0">
                  {new Date(log.created_at).toLocaleString("ar-DZ")}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
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
