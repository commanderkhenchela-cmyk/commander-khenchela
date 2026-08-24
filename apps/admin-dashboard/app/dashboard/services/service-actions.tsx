"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function ServiceActions({
  serviceId,
  enabled,
}: {
  serviceId: string;
  enabled: boolean;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function toggleEnabled() {
    setLoading(true);
    const supabase = createClient();
    await supabase
      .from("services")
      .update({ enabled: !enabled })
      .eq("id", serviceId);
    router.refresh();
    setLoading(false);
  }

  return (
    <button
      onClick={toggleEnabled}
      disabled={loading}
      className="text-sm font-medium text-primary disabled:opacity-50"
    >
      {enabled ? "إخفاء عن العملاء" : "تفعيل"}
    </button>
  );
}
