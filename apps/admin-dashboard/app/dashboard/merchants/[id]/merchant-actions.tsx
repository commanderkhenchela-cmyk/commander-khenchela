"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { MerchantStatus } from "@/lib/types";

export default function MerchantActions({
  merchantId,
  status,
}: {
  merchantId: string;
  status: MerchantStatus;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function setStatus(newStatus: MerchantStatus) {
    if (
      newStatus === "rejected" &&
      !confirm("هل أنت متأكد من رفض هذا المحل؟")
    )
      return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("merchants")
      .update({ status: newStatus })
      .eq("id", merchantId);

    if (error) {
      setError("تعذّر تحديث حالة المحل.");
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
            إلغاء الموافقة (رفض المحل)
          </button>
        )}
        {status === "rejected" && (
          <button
            onClick={() => setStatus("approved")}
            disabled={loading}
            className="block mt-2 text-primary font-medium"
          >
            الموافقة على المحل الآن
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
          الموافقة على المحل
        </button>
        <button
          onClick={() => setStatus("rejected")}
          disabled={loading}
          className="rounded-lg border border-error text-error font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
        >
          رفض المحل
        </button>
      </div>
      {error && <p className="text-error text-sm">{error}</p>}
    </div>
  );
}
