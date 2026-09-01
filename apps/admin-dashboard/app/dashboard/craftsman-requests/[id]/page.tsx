import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { CraftsmanRequest } from "@/lib/types";
import { CRAFT_TYPE_LABELS } from "@/lib/types";
import CraftsmanRequestActions from "./craftsman-request-actions";
import EntityActivityLog from "@/components/entity-activity-log";

export default async function CraftsmanRequestDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.hasCapability("order.view")) redirect("/dashboard");

  const { id } = await params;
  const supabase = await createClient();

  const { data: request } = await supabase
    .from("craftsman_requests")
    .select(
      "id, customer_id, craft_type, description, status, assigned_craftsman_name, " +
        "assigned_craftsman_phone, admin_notes, created_at, assigned_at, completed_at, " +
        "addresses(address_text, phone, communes(name)), users(full_name, phone)",
    )
    .eq("id", id)
    .maybeSingle();

  if (!request) notFound();

  const r = request as unknown as CraftsmanRequest;

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">
        {CRAFT_TYPE_LABELS[r.craft_type]}
      </h1>
      <p className="text-black/60 mb-6">
        تاريخ الطلب: {new Date(r.created_at).toLocaleString("ar-DZ")}
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">بيانات العميل</p>
        <InfoRow label="الاسم" value={r.users?.full_name ?? "—"} />
        <InfoRow label="الهاتف" value={r.users?.phone ?? "—"} />
        <InfoRow
          label="العنوان"
          value={
            r.addresses
              ? `${r.addresses.communes?.name ?? ""} — ${r.addresses.address_text}`
              : "—"
          }
        />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">وصف الطلب</p>
        <p className="text-sm whitespace-pre-wrap">{r.description}</p>
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">الإجراء</p>
        <CraftsmanRequestActions
          requestId={r.id}
          status={r.status}
          assignedCraftsmanName={r.assigned_craftsman_name}
          assignedCraftsmanPhone={r.assigned_craftsman_phone}
          adminNotes={r.admin_notes}
        />
      </div>

      <EntityActivityLog tableName="craftsman_requests" recordId={r.id} />
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
