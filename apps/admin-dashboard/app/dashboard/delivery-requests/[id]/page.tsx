import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { DeliveryRequest } from "@/lib/types";
import { DELIVERY_REQUEST_TYPE_LABELS } from "@/lib/types";
import DeliveryRequestActions from "./delivery-request-actions";
import EntityActivityLog from "@/components/entity-activity-log";

export default async function DeliveryRequestDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.hasCapability("order.view")) redirect("/dashboard");

  const { id } = await params;
  const supabase = await createClient();

  const { data: request } = await supabase
    .from("delivery_requests")
    .select(
      "id, customer_id, description, status, request_type, destination_text, " +
        "delivery_fee, driver_earning_share, created_at, accepted_at, " +
        "addresses(address_text, phone, communes(name)), users(full_name, phone), " +
        "drivers(full_name, phone)",
    )
    .eq("id", id)
    .maybeSingle();

  if (!request) notFound();

  const r = request as unknown as DeliveryRequest;
  const isSend = r.request_type === "send";

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">
        {DELIVERY_REQUEST_TYPE_LABELS[r.request_type]}
      </h1>
      <p className="text-black/60 mb-6">
        تاريخ الطلب: {new Date(r.created_at).toLocaleString("ar-DZ")}
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">بيانات العميل</p>
        <InfoRow label="الاسم" value={r.users?.full_name ?? "—"} />
        <InfoRow label="الهاتف" value={r.users?.phone ?? "—"} />
        <InfoRow
          label={isSend ? "نقطة الاستلام (عنوان العميل)" : "عنوان التسليم"}
          value={
            r.addresses
              ? `${r.addresses.communes?.name ?? ""} — ${r.addresses.address_text}`
              : "—"
          }
        />
        {isSend && (
          <InfoRow
            label="الوجهة (إلى من/أين يُرسَل)"
            value={r.destination_text ?? "—"}
          />
        )}
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">وصف الطلب</p>
        <p className="text-sm whitespace-pre-wrap">{r.description}</p>
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">الموصّل والرسوم</p>
        <InfoRow label="الموصّل" value={r.drivers?.full_name ?? "لم يُعيَّن بعد"} />
        <InfoRow label="هاتف الموصّل" value={r.drivers?.phone ?? "—"} />
        <InfoRow
          label="رسم التوصيل"
          value={
            r.delivery_fee > 0
              ? `${r.delivery_fee.toFixed(0)} دج`
              : "تُحدَّد عند القبول"
          }
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
        <DeliveryRequestActions requestId={r.id} status={r.status} />
      </div>

      <EntityActivityLog tableName="delivery_requests" recordId={r.id} />
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
