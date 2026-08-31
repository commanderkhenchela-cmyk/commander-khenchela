"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";

export default function ProductActions({
  productId,
  isActive,
}: {
  productId: string;
  isActive: boolean;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);

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
        onClick={() => setConfirmOpen(true)}
        disabled={loading}
        className="text-sm font-medium text-error px-2 py-1.5 disabled:opacity-50"
      >
        حذف
      </button>

      <ConfirmDialog
        open={confirmOpen}
        title="هل أنت متأكد من حذف هذا المنتج نهائيًا؟"
        danger
        loading={loading}
        confirmLabel="حذف"
        onCancel={() => setConfirmOpen(false)}
        onConfirm={async () => {
          await deleteProduct();
          setConfirmOpen(false);
        }}
      />
    </div>
  );
}
