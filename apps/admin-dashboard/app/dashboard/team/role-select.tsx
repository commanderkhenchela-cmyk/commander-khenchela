"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { ROLE_LABELS, type UserRole } from "@/lib/types";

const ASSIGNABLE_ROLES: UserRole[] = [
  "admin",
  "manager",
  "ads_manager",
  "merchant",
  "customer",
];

export default function RoleSelect({
  userId,
  currentRole,
  disableSelfDemotion,
}: {
  userId: string;
  currentRole: UserRole;
  disableSelfDemotion: boolean;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const newRole = e.target.value as UserRole;
    if (newRole === currentRole) return;

    if (disableSelfDemotion && newRole !== "admin") {
      const confirmed = confirm(
        "أنت توشك تغيير دورك الخاص بعيدًا عن Super Admin — ستفقد الوصول لهذه الصفحة وصفحات الإدارة الأخرى فورًا، ولن يقدر أحد يرجعك إلا عبر Supabase Dashboard مباشرة. متأكد؟",
      );
      if (!confirmed) {
        e.target.value = currentRole;
        return;
      }
    }

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.rpc("admin_set_user_role", {
      p_user_id: userId,
      p_new_role: newRole,
    });

    if (error) {
      setError("تعذّر تغيير الدور.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  return (
    <div className="shrink-0 text-left">
      <select
        defaultValue={currentRole}
        onChange={handleChange}
        disabled={loading}
        className="rounded-lg border border-border px-2.5 py-1.5 text-sm outline-none focus:border-primary disabled:opacity-60"
      >
        {ASSIGNABLE_ROLES.map((role) => (
          <option key={role} value={role}>
            {ROLE_LABELS[role]}
          </option>
        ))}
      </select>
      {error && <p className="text-error text-xs mt-1">{error}</p>}
    </div>
  );
}
