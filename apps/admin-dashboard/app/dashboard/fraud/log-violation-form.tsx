"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { FraudRole } from "@/lib/types";
import { FRAUD_ROLE_LABELS } from "@/lib/types";

const VIOLATION_TYPES = [
  { value: "order_cancellation", label: "إلغاء طلبات متكرر" },
  { value: "out_of_system_deal", label: "محاولة تنفيذ الطلب خارج النظام" },
  { value: "unregistered_order", label: "عدم تسجيل الطلبية" },
  { value: "payment_avoidance", label: "محاولة عدم دفع المستحقات" },
  { value: "suspicious_behavior", label: "سلوك مشبوه" },
  { value: "abuse", label: "إساءة استخدام النظام" },
];

/**
 * تسجيل مخالفة يدويًا لأي مستخدم — البحث عنه برقم هاتفه (لا قائمة
 * منسدلة عملية لعدد كبير من المستخدمين). يبحث مباشرة فـ users (متاحة
 * للإدارة عبر users_select_admin)، ثم يستدعي admin_log_fraud_violation.
 */
export default function LogViolationForm() {
  const router = useRouter();
  const [phone, setPhone] = useState("");
  const [role, setRole] = useState<FraudRole>("customer");
  const [violationType, setViolationType] = useState(VIOLATION_TYPES[0].value);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    const supabase = createClient();
    const { data: user, error: lookupError } = await supabase
      .from("users")
      .select("id")
      .eq("phone", phone.trim())
      .maybeSingle();

    if (lookupError || !user) {
      setError("لم يتم العثور على مستخدم بهذا الرقم.");
      setLoading(false);
      return;
    }

    const { error } = await supabase.rpc("admin_log_fraud_violation", {
      p_user_id: user.id,
      p_role: role,
      p_violation_type: violationType,
      p_reason: reason || null,
    });

    if (error) {
      setError(error.message || "تعذّر تسجيل المخالفة.");
      setLoading(false);
      return;
    }

    setSaved(true);
    setPhone("");
    setReason("");
    router.refresh();
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} className="grid gap-3 sm:grid-cols-2">
      <div>
        <label className="block text-sm font-medium mb-1">رقم هاتف المستخدم</label>
        <input
          type="text"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          required
          className="w-full rounded-lg border border-border px-3 py-2.5 text-sm outline-none focus:border-primary"
        />
      </div>
      <div>
        <label className="block text-sm font-medium mb-1">الدور</label>
        <select
          value={role}
          onChange={(e) => setRole(e.target.value as FraudRole)}
          className="w-full rounded-lg border border-border px-3 py-2.5 text-sm outline-none focus:border-primary"
        >
          {(Object.keys(FRAUD_ROLE_LABELS) as FraudRole[]).map((r) => (
            <option key={r} value={r}>
              {FRAUD_ROLE_LABELS[r]}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label className="block text-sm font-medium mb-1">نوع المخالفة</label>
        <select
          value={violationType}
          onChange={(e) => setViolationType(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 text-sm outline-none focus:border-primary"
        >
          {VIOLATION_TYPES.map((v) => (
            <option key={v.value} value={v.value}>
              {v.label}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label className="block text-sm font-medium mb-1">تفاصيل (اختياري)</label>
        <input
          type="text"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 text-sm outline-none focus:border-primary"
        />
      </div>
      <div className="sm:col-span-2 flex items-center gap-3">
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-primary text-white font-semibold px-5 py-2.5 text-sm disabled:opacity-60"
        >
          تسجيل المخالفة
        </button>
        {error && <p className="text-error text-xs">{error}</p>}
        {saved && !error && <p className="text-primary text-xs">تم التسجيل</p>}
      </div>
    </form>
  );
}
