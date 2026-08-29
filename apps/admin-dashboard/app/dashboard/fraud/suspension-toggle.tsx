"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function SuspensionToggle({
  userId,
  isSuspended,
}: {
  userId: string;
  isSuspended: boolean;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function toggle() {
    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.rpc("admin_set_suspension", {
      p_user_id: userId,
      p_suspended: !isSuspended,
    });
    setLoading(false);
    if (!error) router.refresh();
  }

  return (
    <button
      onClick={toggle}
      disabled={loading}
      className={`shrink-0 rounded-lg px-4 py-2 text-sm font-semibold disabled:opacity-60 ${
        isSuspended
          ? "border border-primary text-primary"
          : "bg-error text-white"
      }`}
    >
      {isSuspended ? "رفع الإيقاف" : "إيقاف الحساب"}
    </button>
  );
}
