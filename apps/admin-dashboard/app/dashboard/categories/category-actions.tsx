"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function CategoryActions({
  categoryId,
  isActive,
}: {
  categoryId: string;
  isActive: boolean;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function toggleActive() {
    setLoading(true);
    const supabase = createClient();
    await supabase
      .from("categories")
      .update({ is_active: !isActive })
      .eq("id", categoryId);
    router.refresh();
    setLoading(false);
  }

  return (
    <button
      onClick={toggleActive}
      disabled={loading}
      className="text-sm font-medium text-primary px-2 py-1.5 disabled:opacity-50"
    >
      {isActive ? "إخفاء" : "تفعيل"}
    </button>
  );
}
