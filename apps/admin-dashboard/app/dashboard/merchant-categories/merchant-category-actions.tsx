"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function MerchantCategoryActions({
  categoryId,
  icon,
  name,
  isActive,
  isFirst,
  isLast,
  prevId,
  prevSortOrder,
  nextId,
  nextSortOrder,
  currentSortOrder,
}: {
  categoryId: string;
  icon: string;
  name: string;
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
  const [editIcon, setEditIcon] = useState(icon);
  const [editName, setEditName] = useState(name);
  const [error, setError] = useState<string | null>(null);

  async function toggleActive() {
    setLoading(true);
    const supabase = createClient();
    await supabase
      .from("merchant_categories")
      .update({ is_active: !isActive })
      .eq("id", categoryId);
    router.refresh();
    setLoading(false);
  }

  async function move(direction: "up" | "down") {
    const otherId = direction === "up" ? prevId : nextId;
    const otherSortOrder = direction === "up" ? prevSortOrder : nextSortOrder;
    if (!otherId || otherSortOrder === null) return;

    setLoading(true);
    const supabase = createClient();
    // تبديل ترتيب هذا التصنيف مع جاره — لا حاجة لإعادة ترقيم القائمة كلها.
    await supabase
      .from("merchant_categories")
      .update({ sort_order: otherSortOrder })
      .eq("id", categoryId);
    await supabase
      .from("merchant_categories")
      .update({ sort_order: currentSortOrder })
      .eq("id", otherId);
    router.refresh();
    setLoading(false);
  }

  async function saveEdit() {
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("merchant_categories")
      .update({ icon: editIcon.trim() || "🛍️", name: editName })
      .eq("id", categoryId);

    if (error) {
      setError("تعذّر حفظ التعديل.");
      setLoading(false);
      return;
    }

    setEditing(false);
    router.refresh();
    setLoading(false);
  }

  async function remove() {
    if (
      !confirm(
        `حذف تصنيف "${name}" نهائيًا؟ لن ينجح الحذف إذا كانت هناك محلات مرتبطة به.`,
      )
    )
      return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("merchant_categories")
      .delete()
      .eq("id", categoryId);

    if (error) {
      setError("تعذّر الحذف — يوجد محلات مرتبطة بهذا التصنيف. أخفِه بدل حذفه.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  if (editing) {
    return (
      <div className="flex items-center gap-1.5">
        <input
          value={editIcon}
          onChange={(e) => setEditIcon(e.target.value)}
          maxLength={4}
          className="w-12 rounded-lg border border-border px-1 py-1.5 text-center outline-none focus:border-primary"
        />
        <input
          value={editName}
          onChange={(e) => setEditName(e.target.value)}
          className="w-28 rounded-lg border border-border px-2 py-1.5 outline-none focus:border-primary"
        />
        <button
          onClick={saveEdit}
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
        className="text-black/50 disabled:opacity-20 px-1"
      >
        ▲
      </button>
      <button
        onClick={() => move("down")}
        disabled={loading || isLast}
        title="تحريك لأسفل"
        className="text-black/50 disabled:opacity-20 px-1"
      >
        ▼
      </button>
      <button
        onClick={() => setEditing(true)}
        disabled={loading}
        className="text-sm font-medium text-primary px-2 py-1.5"
      >
        تعديل
      </button>
      <button
        onClick={toggleActive}
        disabled={loading}
        className="text-sm font-medium text-primary px-2 py-1.5 disabled:opacity-50"
      >
        {isActive ? "إخفاء" : "تفعيل"}
      </button>
      <button
        onClick={remove}
        disabled={loading}
        className="text-sm font-medium text-error px-2 py-1.5 disabled:opacity-50"
      >
        حذف
      </button>
      {error && <p className="text-error text-xs">{error}</p>}
    </div>
  );
}
