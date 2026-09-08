import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { RideRequest } from "@/lib/types";
import RideRequestActions from "./ride-request-actions";
import EntityActivityLog from "@/components/entity-activity-log";

export default async function RideRequestDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.hasCapability("order.view")) redirect("/dashboard");

  const { id } = await params;
  const supabase = await createClient();

  const { data: request } = await supabase
    .from("ride_requests")
    .select(
      "id, customer_id, status, fare, driver_earning_share, created_at, " +
        "accepted_at, started_at, completed_at, users(full_name, phone), " +
        "drivers(full_name, phone), " +
        "pickup_address:addresses!pickup_address_id(address_text, phone, communes(name)), " +
        "dropoff_address:addresses!dropoff_address_id(address_text, phone, communes(name))",
    )
    .eq("id", id)
    .maybeSingle();

  if (!request) notFound();

  const r = request as unknown as RideRequest;

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">رحلة طاكسي</h1>
      <p className="text-black/60 mb-6">
        تاريخ الطلب: {new Date(r.created_at).toLocaleString("ar-DZ")}
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">بيانات الراكب</p>
        <InfoRow label="الاسم" value={r.users?.full_name ?? "—"} />
        <InfoRow label="الهاتف" value={r.users?.phone ?? "—"} />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">المسار</p>
        <InfoRow
          label="نقطة الانطلاق"
          value={
            r.pickup_address
              ? `${r.pickup_address.communes?.name ?? ""} — ${r.pickup_address.address_text}`
              : "—"
          }
        />
        <InfoRow
          label="الوجهة"
          value={
            r.dropoff_address
              ? `${r.dropoff_address.communes?.name ?? ""} — ${r.dropoff_address.address_text}`
              : "—"
          }
        />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">الموصّل والأجرة</p>
        <InfoRow label="الموصّل" value={r.drivers?.full_name ?? "لم يُعيَّن بعد"} />
        <InfoRow label="هاتف الموصّل" value={r.drivers?.phone ?? "—"} />
        <InfoRow
          label="الأجرة"
          value={r.fare > 0 ? `${r.fare.toFixed(0)} دج` : "تُحدَّد عند القبول"}
        />
        <InfoRow
          label="نصيب الموصّل"
          value={
            r.driver_earning_share > 0
              ? `${r.driver_earning_share.toFixed(0)} دج`
              : "—"
          }
        />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">الإجراء</p>
        <RideRequestActions requestId={r.id} status={r.status} />
      </div>

      <EntityActivityLog tableName="ride_requests" recordId={r.id} />
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
