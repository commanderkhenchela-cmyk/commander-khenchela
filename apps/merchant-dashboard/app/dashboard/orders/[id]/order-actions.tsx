"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { OrderStatus } from "@/lib/types";

/** الانتقالات المسموحة للتاجر فقط (حسب جدول دورة حياة الطلب في Phase 1). */
const MERCHANT_ACTIONS: Partial<
  Record<OrderStatus, { to: OrderStatus; label: string; danger?: boolean }[]>
> = {
  pending: [
    { to: "confirmed", label: "تأكيد الطلب" },
    { to: "rejected", label: "رفض الطلب", danger: true },
  ],
  confirmed: [{ to: "preparing", label: "بدء التجهيز" }],
  preparing: [{ to: "ready_for_pickup", label: "جاهز للاستلام" }],
};

export default function OrderActions({
  orderId,
  status,
}: {
  orderId: string;
  status: OrderStatus;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const actions = MERCHANT_ACTIONS[status];

  if (!actions) {
    return (
      <p className="text-sm text-black/50">
        لا يوجد إجراء متاح لك على هذا الطلب في حالته الحالية.
      </p>
    );
  }

  async function updateStatus(to: OrderStatus, danger?: boolean) {
    if (danger && !confirm("هل أنت متأكد من رفض هذا الطلب؟")) return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("orders")
      .update({ status: to })
      .eq("id", orderId);

    if (error) {
      setError("تعذّر تحديث حالة الطلب.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-3">
        {actions.map((action) => (
          <button
            key={action.to}
            disabled={loading}
            onClick={() => updateStatus(action.to, action.danger)}
            className={`rounded-lg font-semibold px-4 py-2.5 text-sm disabled:opacity-60 ${
              action.danger
                ? "border border-error text-error"
                : "bg-primary text-white"
            }`}
          >
            {action.label}
          </button>
        ))}
      </div>
      {error && <p className="text-error text-sm">{error}</p>}
    </div>
  );
}
