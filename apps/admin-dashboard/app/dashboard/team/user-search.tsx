"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { ROLE_LABELS, type TeamMember, type UserRole } from "@/lib/types";

const GRANTABLE_ROLES: UserRole[] = ["manager", "ads_manager", "admin"];

export default function UserSearch() {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<TeamMember[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [assignedId, setAssignedId] = useState<string | null>(null);

  async function handleSearch(e: React.FormEvent) {
    e.preventDefault();
    if (!query.trim()) return;

    setLoading(true);
    setError(null);
    setAssignedId(null);
    const supabase = createClient();
    const { data, error } = await supabase
      .from("users")
      .select("id, full_name, phone, role, created_at")
      .ilike("full_name", `%${query.trim()}%`)
      .limit(10);

    if (error) {
      setError("تعذّر البحث.");
      setLoading(false);
      return;
    }

    setResults((data ?? []) as TeamMember[]);
    setLoading(false);
  }

  async function grantRole(userId: string, role: UserRole) {
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.rpc("admin_set_user_role", {
      p_user_id: userId,
      p_new_role: role,
    });

    if (error) {
      setError("تعذّر منح الدور.");
      return;
    }

    setAssignedId(userId);
    router.refresh();
  }

  return (
    <div>
      <form onSubmit={handleSearch} className="flex gap-2 mb-3">
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="ابحث بالاسم..."
          className="flex-1 rounded-lg border border-border px-3 py-2 text-sm outline-none focus:border-primary"
        />
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-primary text-white text-sm font-semibold px-4 disabled:opacity-60"
        >
          بحث
        </button>
      </form>

      {error && <p className="text-error text-sm mb-2">{error}</p>}

      {results.length > 0 && (
        <div className="grid gap-2">
          {results.map((user) => (
            <div
              key={user.id}
              className="rounded-lg bg-background p-3 flex items-center justify-between gap-3"
            >
              <div className="min-w-0">
                <p className="text-sm font-medium truncate">
                  {user.full_name || "بدون اسم"}
                </p>
                <p className="text-xs text-black/50">
                  {ROLE_LABELS[user.role]}
                </p>
              </div>
              {assignedId === user.id ? (
                <span className="text-primary text-xs font-semibold shrink-0">
                  تم ✓
                </span>
              ) : (
                <div className="flex gap-1 shrink-0">
                  {GRANTABLE_ROLES.map((role) => (
                    <button
                      key={role}
                      onClick={() => grantRole(user.id, role)}
                      className="text-xs rounded-full border border-border px-2.5 py-1 hover:border-primary hover:text-primary"
                    >
                      {ROLE_LABELS[role]}
                    </button>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
