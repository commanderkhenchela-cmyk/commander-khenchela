"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { CraftsmanRequestStatus } from "@/lib/types";

/**
 * الإجراء الإداري الوحيد فـ "حرفيون" V1: ربط الطلب يدويًا ببيانات
 * تواصل حرفي حقيقي (اسم/هاتف كنص حرّ — لا حساب حرفي بعد، راجع تعليق
 * migration 20260907000000)، ثم إتمامه لاحقًا. نفس نمط
 * DeliveryFeeOverrideForm (RPC + رسالة الخطأ الحقيقية من السيرفر).
 */
export default function CraftsmanRequestActions({
  requestId,
  status,
  assignedCraftsmanName,
  assignedCraftsmanPhone,
  adminNotes,
}: {
  requestId: string;
  status: CraftsmanRequestStatus;
  assignedCraftsmanName: string | null;
  assignedCraftsmanPhone: string | null;
  adminNotes: string | null;
}) {
  const router = useRouter();
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function assign(e: React.FormEvent) {
    e.preventDefault();
    if (name.trim() === "" || phone.trim() === "") {
      setError("اسم الحرفي وهاتفه مطلوبان.");
      return;
    }

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.rpc("admin_assign_craftsman_request", {
      p_request_id: requestId,
      p_craftsman_name: name.trim(),
      p_craftsman_phone: phone.trim(),
      p_notes: notes.trim() === "" ? null : notes.trim(),
    });

    if (error) {
      setError(error.message || "تعذّر ربط الطلب بحرفي.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  async function complete() {
    if (!confirm("تأكيد إتمام هذا الطلب؟")) return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.rpc("admin_complete_craftsman_request", {
      p_request_id: requestId,
    });

    if (error) {
      setError(error.message || "تعذّر إتمام الطلب.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  async function cancel() {
    if (!confirm("تأكيد إلغاء هذا الطلب؟")) return;

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("craftsman_requests")
      .update({ status: "cancelled" })
      .eq("id", requestId);

    if (error) {
      setError(error.message || "تعذّر إلغاء الطلب.");
      setLoading(false);
      return;
    }

    router.refresh();
    setLoading(false);
  }

  if (status === "completed") {
    return <p className="text-sm text-black/50">اكتمل هذا الطلب.</p>;
  }

  if (status === "cancelled") {
    return <p className="text-sm text-black/50">أُلغي هذا الطلب.</p>;
  }

  if (status === "assigned") {
    return (
      <div className="flex flex-col gap-3">
        <div className="rounded-lg bg-primary/10 p-3 text-sm">
          <p className="font-semibold">{assignedCraftsmanName}</p>
          <p className="text-black/70">{assignedCraftsmanPhone}</p>
          {adminNotes && <p className="text-black/60 mt-1">{adminNotes}</p>}
        </div>
        <div className="flex gap-3">
          <button
            onClick={complete}
            disabled={loading}
            className="rounded-lg bg-primary text-white font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
          >
            تم إتمام العمل
          </button>
          <button
            onClick={cancel}
            disabled={loading}
            className="rounded-lg border border-error text-error font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
          >
            إلغاء الطلب
          </button>
        </div>
        {error && <p className="text-error text-sm">{error}</p>}
      </div>
    );
  }

  // pending
  return (
    <form onSubmit={assign} className="flex flex-col gap-2">
      <input
        type="text"
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="اسم الحرفي"
        className="rounded-lg border border-border px-3 py-2 text-sm outline-none focus:border-primary"
      />
      <input
        type="tel"
        value={phone}
        onChange={(e) => setPhone(e.target.value)}
        placeholder="هاتف الحرفي"
        className="rounded-lg border border-border px-3 py-2 text-sm outline-none focus:border-primary"
      />
      <input
        type="text"
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        placeholder="ملاحظات (اختياري)"
        className="rounded-lg border border-border px-3 py-2 text-sm outline-none focus:border-primary"
      />
      <div className="flex gap-3 mt-1">
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-primary text-white font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
        >
          ربط بحرفي
        </button>
        <button
          type="button"
          onClick={cancel}
          disabled={loading}
          className="rounded-lg border border-error text-error font-semibold px-4 py-2.5 text-sm disabled:opacity-60"
        >
          إلغاء الطلب
        </button>
      </div>
      {error && <p className="text-error text-sm">{error}</p>}
    </form>
  );
}
