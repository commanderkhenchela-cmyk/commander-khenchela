"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type PendingApprovalStatus = "pending" | "approved" | "rejected";

/**
 * موافقة/رفض كيان (موصّل أو محل) بحالة pending/approved/rejected — نفس
 * نمط WalletTopupForm/WalletSection: مُوحَّد من نسختين متطابقتين تقريبًا
 * (driver-actions.tsx وmerchant-actions.tsx)، الفرق فقط اسم الجدول
 * ونصوص التسميات العربية.
 */
export default function EntityStatusActions({
  tableName,
  entityId,
  status,
  entityLabel,
}: {
  tableName: "drivers" | "merchants";
  entityId: string;
  status: PendingApprovalStatus;
  /** الاسم العربي المستخدَم فـ الرسائل — "الموصّل" أو "المحل". */
  entityLabel: string;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function setStatus(newStatus: PendingApprovalStatus) {
    if (
      newStatus === "rejected" &&
      !confirm(`هل أنت متأكد من رفض هذا ${entityLabel}؟`)
    )
      return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from(tableName)
      .update({ status: newStatus })
      .eq("id", entityId);

    if (error) {
      setError(`تعذّر تحديث حالة ${entityLabel}.`);
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  if (status !== "pending") {
    return (
      <p className="text-sm text-black/50">
        لا يوجد إجراء إضافي — يمكنك تغيير القرار لاحقًا عند الحاجة أدناه.
        {status === "approved" && (
          <button
            onClick={() => setStatus("rejected")}
            disabled={loading}
            className="block mt-2 text-error font-medium"
          >
            إلغاء الموافقة (رفض {entityLabel})
          </button>
        )}
        {status === "rejected" && (
          <button
            onClick={() => setStatus("approved")}
            disabled={loading}
            className="block mt-2 text-primary font-medium"
          >
            الموافقة على {entityLabel} الآن
          </button>
        )}
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-3">
        <button
          onClick={() => setStatus("approved")}
          disabled={loading}
          className="rounded-lg bg-primary text-white font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
        >
          الموافقة على {entityLabel}
        </button>
        <button
          onClick={() => setStatus("rejected")}
          disabled={loading}
          className="rounded-lg border border-error text-error font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
        >
          رفض {entityLabel}
        </button>
      </div>
      {error && <p className="text-error text-sm">{error}</p>}
    </div>
  );
}
