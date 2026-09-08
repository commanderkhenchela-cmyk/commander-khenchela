"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { RideRequestStatus } from "@/lib/types";

/**
 * الإجراء الإداري الوحيد هنا: الإلغاء الطارئ — لكن فقط طالما الحالة
 * pending أو accepted. بمجرد in_progress (الراكب فـ السيارة فعليًا)
 * لا يسمح validate_ride_request_status_transition بأي إلغاء إطلاقًا —
 * فقط in_progress -> completed. لا نعرض زرًا سيفشل حتمًا؛ نعرض رسالة
 * توضيحية بدلًا منه. نفس هيكل delivery-request-actions.tsx.
 */
export default function RideRequestActions({
  requestId,
  status,
}: {
  requestId: string;
  status: RideRequestStatus;
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function cancel() {
    if (!confirm("تأكيد إلغاء هذه الرحلة؟")) return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("ride_requests")
      .update({ status: "cancelled" })
      .eq("id", requestId);

    if (error) {
      setError(error.message || "تعذّر إلغاء الرحلة.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  if (status === "completed") {
    return <p className="text-sm text-black/50">اكتملت هذه الرحلة.</p>;
  }

  if (status === "cancelled") {
    return <p className="text-sm text-black/50">أُلغيت هذه الرحلة.</p>;
  }

  if (status === "in_progress") {
    return (
      <p className="text-sm text-black/50">
        الرحلة جارية الآن — لا يمكن إلغاؤها بعد صعود الراكب، فقط إتمامها
        من طرف الموصّل.
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <button
        onClick={cancel}
        disabled={loading}
        className="rounded-lg border border-error text-error font-semibold px-4 py-2.5 text-sm disabled:opacity-60 self-start"
      >
        إلغاء الرحلة
      </button>
      {error && <p className="text-error text-sm">{error}</p>}
    </div>
  );
}
