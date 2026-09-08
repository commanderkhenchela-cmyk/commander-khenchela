"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { DeliveryRequestStatus } from "@/lib/types";

/**
 * الإجراء الإداري الوحيد هنا: الإلغاء. لا تعيين يدوي (بخلاف حرفيون) —
 * الموصّل يقبل الطلب بنفسه من مجمع driver_app، فلا شيء تفعله الإدارة
 * فـ دورة الحياة العادية. يبقى للإدارة صلاحية الإلغاء وقت pending أو
 * accepted (راجع validate_delivery_request_status_transition) لحالات
 * الطوارئ فقط.
 */
export default function DeliveryRequestActions({
  requestId,
  status,
}: {
  requestId: string;
  status: DeliveryRequestStatus;
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function cancel() {
    if (!confirm("تأكيد إلغاء هذا الطلب؟")) return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("delivery_requests")
      .update({ status: "cancelled" })
      .eq("id", requestId);

    if (error) {
      setError(error.message || "تعذّر إلغاء الطلب.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  if (status === "delivered") {
    return <p className="text-sm text-black/50">اكتمل هذا الطلب.</p>;
  }

  if (status === "cancelled") {
    return <p className="text-sm text-black/50">أُلغي هذا الطلب.</p>;
  }

  return (
    <div className="flex flex-col gap-3">
      <button
        onClick={cancel}
        disabled={loading}
        className="rounded-lg border border-error text-error font-semibold px-4 py-2.5 text-sm disabled:opacity-60 self-start"
      >
        إلغاء الطلب
      </button>
      {error && <p className="text-error text-sm">{error}</p>}
    </div>
  );
}
