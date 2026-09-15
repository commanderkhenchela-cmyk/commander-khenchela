"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * إلغاء طارئ إداري لطلب (رحلة Taxi أو طلب توصيل) طالما لم يصل لحالة
 * نهائية — نفس نمط WalletTopupForm/EntityStatusActions: مُوحَّد من
 * نسختين شبه متطابقتين (ride-request-actions.tsx وdelivery-request-
 * actions.tsx). عدد/نصوص الحالات النهائية يختلف بين الاثنين (الرحلة
 * عندها حالة "in_progress" إضافية لا إلغاء فيها)، لذا `terminalMessages`
 * خريطة مفتوحة: أي status موجود فيها يُعرض كرسالة بدل زر الإلغاء.
 */
export default function RequestCancelActions({
  tableName,
  requestId,
  status,
  cancelConfirmText,
  cancelErrorText,
  cancelButtonText,
  terminalMessages,
}: {
  tableName: "ride_requests" | "delivery_requests";
  requestId: string;
  status: string;
  cancelConfirmText: string;
  cancelErrorText: string;
  cancelButtonText: string;
  terminalMessages: Record<string, string>;
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function cancel() {
    if (!confirm(cancelConfirmText)) return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from(tableName)
      .update({ status: "cancelled" })
      .eq("id", requestId);

    if (error) {
      setError(error.message || cancelErrorText);
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  const terminalMessage = terminalMessages[status];
  if (terminalMessage) {
    return <p className="text-sm text-black/50">{terminalMessage}</p>;
  }

  return (
    <div className="flex flex-col gap-3">
      <button
        onClick={cancel}
        disabled={loading}
        className="rounded-lg border border-error text-error font-semibold px-4 py-2.5 text-sm disabled:opacity-60 self-start"
      >
        {cancelButtonText}
      </button>
      {error && <p className="text-error text-sm">{error}</p>}
    </div>
  );
}
