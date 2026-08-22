import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Driver } from "@/lib/types";
import DriverActions from "./driver-actions";

export default async function DriverDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: driver } = await supabase
    .from("drivers")
    .select(
      "id, user_id, full_name, phone, vehicle_type, status, is_online, created_at",
    )
    .eq("id", id)
    .maybeSingle();

  if (!driver) notFound();

  const { data: account } = await supabase
    .from("users")
    .select("created_at")
    .eq("id", driver.user_id)
    .maybeSingle();

  const { count: activeJobsCount } = await supabase
    .from("orders")
    .select("id", { count: "exact", head: true })
    .eq("driver_id", id)
    .not("status", "in", "(delivered,cancelled,rejected)");

  const d = driver as Driver;

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">{d.full_name}</h1>
      <p className="text-black/60 mb-6">
        تاريخ التسجيل: {new Date(d.created_at).toLocaleDateString("ar-DZ")}
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">بيانات الموصّل</p>
        <InfoRow label="الهاتف" value={d.phone} />
        <InfoRow label="نوع المركبة" value="🏍️ دراجة" />
        <InfoRow label="متصل الآن" value={d.is_online ? "نعم" : "لا"} />
        <InfoRow
          label="طلبات قيد التنفيذ حاليًا"
          value={String(activeJobsCount ?? 0)}
        />
        <InfoRow
          label="تاريخ إنشاء الحساب"
          value={
            account?.created_at
              ? new Date(account.created_at).toLocaleDateString("ar-DZ")
              : "—"
          }
        />
      </div>

      <div className="rounded-xl border border-border bg-card p-5">
        <p className="font-semibold mb-3">الإجراء</p>
        <DriverActions driverId={d.id} status={d.status} />
      </div>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between text-sm py-1.5 border-b border-border last:border-b-0">
      <span className="text-black/60">{label}</span>
      <span className="font-medium">{value}</span>
    </div>
  );
}
