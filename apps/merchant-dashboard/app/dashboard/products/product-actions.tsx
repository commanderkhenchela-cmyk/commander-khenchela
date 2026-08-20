"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function ProductActions({
  productId,
  isActive,
}: {
  productId: string;
  isActive: boolean;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function toggleActive() {
    setLoading(true);
    const supabase = createClient();
    await supabase
      .from("products")
      .update({ is_active: !isActive })
      .eq("id", productId);
    router.refresh();
    setLoading(false);
  }

  async function deleteProduct() {
    if (!confirm("هل أنت متأكد من حذف هذا المنتج نهائيًا؟")) return;
    setLoading(true);
    const supabase = createClient();
    await supabase.from("products").delete().eq("id", productId);
    router.refresh();
    setLoading(false);
  }

  return (
    <div className="flex items-center gap-2">
      <button
        onClick={toggleActive}
        disabled={loading}
        className="text-sm font-medium text-black/60 px-2 py-1.5 disabled:opacity-50"
      >
        {isActive ? "إخفاء" : "تفعيل"}
      </button>
      <button
        onClick={deleteProduct}
        disabled={loading}
        className="text-sm font-medium text-error px-2 py-1.5 disabled:opacity-50"
      >
        حذف
      </button>
    </div>
  );
}
