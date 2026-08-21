"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function HomeSectionActions({
  sectionId,
  title,
  isActive,
  isFirst,
  isLast,
  prevId,
  prevSortOrder,
  nextId,
  nextSortOrder,
  currentSortOrder,
}: {
  sectionId: string;
  title: string;
  isActive: boolean;
  isFirst: boolean;
  isLast: boolean;
  prevId: string | null;
  prevSortOrder: number | null;
  nextId: string | null;
  nextSortOrder: number | null;
  currentSortOrder: number;
}) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [editing, setEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(title);
  const [error, setError] = useState<string | null>(null);

  async function toggleActive() {
    setLoading(true);
    const supabase = createClient();
    await supabase
      .from("home_sections")
      .update({ is_active: !isActive })
      .eq("id", sectionId);
    router.refresh();
    setLoading(false);
  }

  async function move(direction: "up" | "down") {
    const otherId = direction === "up" ? prevId : nextId;
    const otherSortOrder = direction === "up" ? prevSortOrder : nextSortOrder;
    if (!otherId || otherSortOrder === null) return;

    setLoading(true);
    const supabase = createClient();
    await supabase
      .from("home_sections")
      .update({ sort_order: otherSortOrder })
      .eq("id", sectionId);
    await supabase
      .from("home_sections")
      .update({ sort_order: currentSortOrder })
      .eq("id", otherId);
    router.refresh();
    setLoading(false);
  }

  async function saveTitle() {
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("home_sections")
      .update({ title: editTitle })
      .eq("id", sectionId);

    if (error) {
      setError("تعذّر الحفظ.");
      setLoading(false);
      return;
    }

    setEditing(false);
    router.refresh();
    setLoading(false);
  }

  if (editing) {
    return (
      <div className="flex items-center gap-1.5">
        <input
          value={editTitle}
          onChange={(e) => setEditTitle(e.target.value)}
          className="w-40 rounded-lg border border-border px-2 py-1 text-sm outline-none focus:border-primary"
        />
        <button
          onClick={saveTitle}
          disabled={loading}
          className="text-sm font-medium text-primary px-1.5"
        >
          حفظ
        </button>
        <button
          onClick={() => setEditing(false)}
          disabled={loading}
          className="text-sm text-black/50 px-1.5"
        >
          إلغاء
        </button>
        {error && <p className="text-error text-xs">{error}</p>}
      </div>
    );
  }

  return (
    <div className="flex items-center gap-1">
      <button
        onClick={() => move("up")}
        disabled={loading || isFirst}
        title="تحريك لأعلى"
        className="text-black/50 disabled:opacity-20 px-1 text-sm"
      >
        ▲
      </button>
      <button
        onClick={() => move("down")}
        disabled={loading || isLast}
        title="تحريك لأسفل"
        className="text-black/50 disabled:opacity-20 px-1 text-sm"
      >
        ▼
      </button>
      <button
        onClick={() => setEditing(true)}
        disabled={loading}
        className="text-sm font-medium text-primary px-2"
      >
        تعديل العنوان
      </button>
      <button
        onClick={toggleActive}
        disabled={loading}
        className="text-sm font-medium text-primary px-2 disabled:opacity-50"
      >
        {isActive ? "إخفاء" : "تفعيل"}
      </button>
    </div>
  );
}
