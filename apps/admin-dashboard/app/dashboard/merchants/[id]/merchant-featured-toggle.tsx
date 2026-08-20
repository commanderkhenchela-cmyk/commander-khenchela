"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function MerchantFeaturedToggle({
  merchantId,
  isFeatured,
}: {
  merchantId: string;
  isFeatured: boolean;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function toggle() {
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("merchants")
      .update({ is_featured: !isFeatured })
      .eq("id", merchantId);

    if (error) {
      setError("تعذّر تحديث حالة التمييز.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  return (
    <div className="flex items-center justify-between gap-3">
      <div>
        <p className="text-sm font-medium">تمييز هذا المحل</p>
        <p className="text-xs text-black/50 mt-0.5">
          يظهر في قسم &quot;مميزة&quot; أعلى صفحة تصنيفه في تطبيق العميل.
        </p>
      </div>
      <button
        onClick={toggle}
        disabled={loading}
        role="switch"
        aria-checked={isFeatured}
        className={`shrink-0 w-11 h-6 rounded-full transition-colors relative disabled:opacity-60 ${
          isFeatured ? "bg-primary" : "bg-black/15"
        }`}
      >
        <span
          className={`absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${
            isFeatured ? "translate-x-[-1.375rem]" : "translate-x-[-0.125rem]"
          } right-0.5`}
        />
      </button>
      {error && <p className="text-error text-xs">{error}</p>}
    </div>
  );
}
