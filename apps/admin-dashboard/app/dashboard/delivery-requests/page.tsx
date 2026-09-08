import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { DeliveryRequest, DeliveryRequestStatus } from "@/lib/types";
import {
  DELIVERY_REQUEST_STATUS_LABELS,
  DELIVERY_REQUEST_TYPE_LABELS,
} from "@/lib/types";

const FILTERS: { value: DeliveryRequestStatus | "all"; label: string }[] = [
  { value: "pending", label: "قيد الانتظار" },
  { value: "accepted", label: "مقبولة" },
  { value: "delivered", label: "تم التسليم" },
  { value: "cancelled", label: "ملغاة" },
  { value: "all", label: "الكل" },
];

/**
 * قائمة طلبات "اطلب أي شيء" — عرض فقط، بلا تعيين يدوي (بخلاف
 * حرفيون): الموصّل يقبل الطلب بنفسه من مجمع driver_app. هذه الصفحة هي
 * تنفيذ مطلب "و الإدارة" — الإدارة كانت الطرف الوحيد الذي لا يرى شيئًا
 * عن هذه الطلبات قبلها (لا صفحة كانت موجودة إطلاقًا). نفس هيكل
 * craftsman-requests/page.tsx بالحرف.
 */
export default async function DeliveryRequestsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.hasCapability("order.view")) redirect("/dashboard");

  const { status } = await searchParams;
  const activeFilter = status ?? "pending";

  const supabase = await createClient();
  let query = supabase
    .from("delivery_requests")
    .select(
      "id, description, status, request_type, destination_text, delivery_fee, created_at, users(full_name, phone)",
    )
    .order("created_at", { ascending: false });

  if (activeFilter !== "all") {
    query = query.eq("status", activeFilter);
  }

  const { data: requests } = await query;
  const items = (requests ?? []) as unknown as DeliveryRequest[];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">اطلب أي شيء</h1>

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        {FILTERS.map((f) => (
          <Link
            key={f.value}
            href={`/dashboard/delivery-requests?status=${f.value}`}
            className={`whitespace-nowrap rounded-full px-4 py-2 text-sm font-medium border ${
              activeFilter === f.value
                ? "bg-primary text-white border-primary"
                : "border-border text-black/70"
            }`}
          >
            {f.label}
          </Link>
        ))}
      </div>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد طلبات فـ هذا التصنيف.</p>
      ) : (
        <div className="grid gap-3">
          {items.map((r) => (
            <Link
              key={r.id}
              href={`/dashboard/delivery-requests/${r.id}`}
              className="rounded-xl border border-border bg-card p-4 flex items-center gap-4"
            >
              <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center shrink-0 text-lg">
                {r.request_type === "send" ? "📤" : "📥"}
              </div>
              <div className="min-w-0 flex-1">
                <p className="font-semibold truncate">
                  {DELIVERY_REQUEST_TYPE_LABELS[r.request_type]} —{" "}
                  {r.users?.full_name ?? "؟"}
                </p>
                <p className="text-sm text-black/60 truncate">
                  {r.description}
                </p>
              </div>
              <StatusBadge status={r.status} />
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

/// نفس نمط StatusBadge فـ craftsman-requests/page.tsx — لون يتبع
/// الحالة الفعلية.
function StatusBadge({ status }: { status: DeliveryRequestStatus }) {
  const colorClass =
    status === "delivered"
      ? "text-primary bg-primary/10"
      : status === "cancelled"
        ? "text-error bg-error/10"
        : "text-warning bg-warning/10";

  return (
    <span
      className={`shrink-0 rounded-full px-3 py-1 text-xs font-semibold ${colorClass}`}
    >
      {DELIVERY_REQUEST_STATUS_LABELS[status]}
    </span>
  );
}
