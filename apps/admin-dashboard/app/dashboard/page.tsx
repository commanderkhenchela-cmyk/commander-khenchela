import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import { tableLabel, type ActivityLogEntry } from "@/lib/types";

export default async function DashboardOverviewPage() {
  const context = await getAdminContext();
  if (!context) return null;
  const supabase = await createClient();

  const canSeeMerchants = context.hasCapability("merchant.view");
  const canSeeDrivers = context.hasCapability("driver.view");
  const canSeeOrders = context.hasCapability("order.view");
  const canSeeServices = context.hasCapability("service.view");
  const canSeeFraud = context.hasCapability("fraud.view");

  const [
    { count: pendingMerchants },
    { count: activeMerchants },
    { count: pendingDrivers },
    { count: onlineDrivers },
    { count: pendingOrders },
    { count: activeOrders },
    { count: totalOrders },
    { count: activeServices },
    { count: totalUsers },
    { count: unreadNotifications },
    { count: suspendedAccounts },
    { data: recentActivity },
  ] = await Promise.all([
    canSeeMerchants
      ? supabase.from("merchants").select("id", { count: "exact", head: true }).eq("status", "pending")
      : Promise.resolve({ count: null }),
    canSeeMerchants
      ? supabase.from("merchants").select("id", { count: "exact", head: true }).eq("status", "approved")
      : Promise.resolve({ count: null }),
    canSeeDrivers
      ? supabase.from("drivers").select("id", { count: "exact", head: true }).eq("status", "pending")
      : Promise.resolve({ count: null }),
    canSeeDrivers
      ? supabase.from("drivers").select("id", { count: "exact", head: true }).eq("is_online", true)
      : Promise.resolve({ count: null }),
    canSeeOrders
      ? supabase.from("orders").select("id", { count: "exact", head: true }).eq("status", "ready_for_pickup")
      : Promise.resolve({ count: null }),
    canSeeOrders
      ? supabase
          .from("orders")
          .select("id", { count: "exact", head: true })
          .not("status", "in", "(delivered,cancelled,rejected)")
      : Promise.resolve({ count: null }),
    canSeeOrders
      ? supabase.from("orders").select("id", { count: "exact", head: true })
      : Promise.resolve({ count: null }),
    canSeeServices
      ? supabase.from("services").select("id", { count: "exact", head: true }).eq("enabled", true)
      : Promise.resolve({ count: null }),
    context.isSuperAdmin
      ? supabase.from("users").select("id", { count: "exact", head: true })
      : Promise.resolve({ count: null }),
    supabase
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("user_id", context.userId)
      .eq("is_read", false),
    canSeeFraud
      ? supabase.from("users").select("id", { count: "exact", head: true }).eq("is_suspended", true)
      : Promise.resolve({ count: null }),
    context.isSuperAdmin
      ? supabase
          .from("admin_activity_log")
          .select("id, admin_name, action, table_name, record_id, created_at")
          .order("created_at", { ascending: false })
          .limit(5)
      : Promise.resolve({ data: null }),
  ]);

  const activity = (recentActivity ?? []) as ActivityLogEntry[];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">نظرة عامة</h1>
      <p className="text-sm text-black/50 mb-6">
        مركز التحكّم — كل رقم أدناه مقروء مباشرة من قاعدة البيانات الآن، لا
        يوجد رقم افتراضي أو تقديري.
      </p>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {context.isSuperAdmin && (
          <StatCard label="إجمالي المستخدمين" value={totalUsers ?? 0} />
        )}
        {canSeeMerchants && (
          <>
            <StatCard
              label="محلات بانتظار الموافقة"
              value={pendingMerchants ?? 0}
              highlight={(pendingMerchants ?? 0) > 0}
            />
            <StatCard label="محلات نشطة" value={activeMerchants ?? 0} />
          </>
        )}
        {canSeeDrivers && (
          <>
            <StatCard
              label="موصّلون بانتظار الموافقة"
              value={pendingDrivers ?? 0}
              highlight={(pendingDrivers ?? 0) > 0}
            />
            <StatCard label="موصّلون متصلون الآن" value={onlineDrivers ?? 0} />
          </>
        )}
        {canSeeOrders && (
          <>
            <StatCard
              label="طلبات جاهزة للاستلام (تحتاج توصيل)"
              value={pendingOrders ?? 0}
              highlight={(pendingOrders ?? 0) > 0}
            />
            <StatCard label="طلبات قيد التنفيذ حاليًا" value={activeOrders ?? 0} />
            <StatCard label="إجمالي الطلبات" value={totalOrders ?? 0} />
          </>
        )}
        {canSeeServices && (
          <StatCard label="خدمات مفعَّلة" value={activeServices ?? 0} />
        )}
        {canSeeFraud && (
          <StatCard
            label="حسابات موقوفة"
            value={suspendedAccounts ?? 0}
            highlight={(suspendedAccounts ?? 0) > 0}
          />
        )}
        <StatCard
          label="إشعاراتي غير المقروءة"
          value={unreadNotifications ?? 0}
          highlight={(unreadNotifications ?? 0) > 0}
        />
      </div>

      <div className="flex gap-3 flex-wrap">
        {canSeeMerchants && (pendingMerchants ?? 0) > 0 && (
          <Link
            href="/dashboard/merchants?status=pending"
            className="rounded-lg bg-primary text-white font-semibold px-5 py-3"
          >
            مراجعة المحلات الجديدة
          </Link>
        )}
        {canSeeDrivers && (pendingDrivers ?? 0) > 0 && (
          <Link
            href="/dashboard/drivers?status=pending"
            className="rounded-lg bg-primary text-white font-semibold px-5 py-3"
          >
            مراجعة الموصّلين الجدد
          </Link>
        )}
        {canSeeOrders && (pendingOrders ?? 0) > 0 && (
          <Link
            href="/dashboard/orders?status=ready_for_pickup"
            className="rounded-lg border border-primary text-primary font-semibold px-5 py-3"
          >
            متابعة التوصيل
          </Link>
        )}
        {canSeeFraud && (suspendedAccounts ?? 0) > 0 && (
          <Link
            href="/dashboard/fraud"
            className="rounded-lg border border-error text-error font-semibold px-5 py-3"
          >
            مراجعة الحسابات الموقوفة
          </Link>
        )}
      </div>

      {context.isSuperAdmin && (
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
