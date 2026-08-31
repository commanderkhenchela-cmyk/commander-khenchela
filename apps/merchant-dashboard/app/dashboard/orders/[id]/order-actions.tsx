"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { OrderStatus } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { FieldError } from "@/components/ui/input";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";

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
  const [pendingDanger, setPendingDanger] = useState<OrderStatus | null>(null);

  const actions = MERCHANT_ACTIONS[status];

  if (!actions) {
    return (
      <p className="text-sm text-black/50">
        لا يوجد إجراء متاح لك على هذا الطلب في حالته الحالية.
      </p>
    );
  }

  async function updateStatus(to: OrderStatus) {
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
          <Button
            key={action.to}
            type="button"
            variant={action.danger ? "danger" : "primary"}
            size="sm"
            disabled={loading}
            onClick={() =>
              action.danger ? setPendingDanger(action.to) : updateStatus(action.to)
            }
          >
            {action.label}
          </Button>
        ))}
      </div>
      <FieldError>{error}</FieldError>

      <ConfirmDialog
        open={pendingDanger !== null}
        title="هل أنت متأكد من رفض هذا الطلب؟"
        danger
        loading={loading}
        confirmLabel="رفض الطلب"
        onCancel={() => setPendingDanger(null)}
        onConfirm={async () => {
          if (!pendingDanger) return;
          await updateStatus(pendingDanger);
          setPendingDanger(null);
        }}
      />
    </div>
  );
}
