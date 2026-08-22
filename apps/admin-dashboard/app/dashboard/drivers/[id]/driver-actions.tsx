"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { DriverStatus } from "@/lib/types";

export default function DriverActions({
  driverId,
  status,
}: {
  driverId: string;
  status: DriverStatus;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function setStatus(newStatus: DriverStatus) {
    if (
      newStatus === "rejected" &&
      !confirm("هل أنت متأكد من رفض هذا الموصّل؟")
    )
      return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("drivers")
      .update({ status: newStatus })
      .eq("id", driverId);

    if (error) {
      setError("تعذّر تحديث حالة الموصّل.");
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
            إلغاء الموافقة (رفض الموصّل)
          </button>
        )}
        {status === "rejected" && (
          <button
            onClick={() => setStatus("approved")}
            disabled={loading}
            className="block mt-2 text-primary font-medium"
          >
            الموافقة على الموصّل الآن
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
          الموافقة على الموصّل
        </button>
        <button
          onClick={() => setStatus("rejected")}
          disabled={loading}
          className="rounded-lg border border-error text-error font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
        >
          رفض الموصّل
        </button>
      </div>
      {error && <p className="text-error text-sm">{error}</p>}
    </div>
  );
}
