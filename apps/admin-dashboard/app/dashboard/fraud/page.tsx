import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { FraudCase } from "@/lib/types";
import { FRAUD_ROLE_LABELS, FRAUD_STATUS_LABELS } from "@/lib/types";
import LogViolationForm from "./log-violation-form";
import SuspensionToggle from "./suspension-toggle";

const STATUS_COLORS: Record<string, string> = {
  open: "text-black/60 bg-black/5",
  warning: "text-warning bg-warning/10",
  suspended: "text-error bg-error/10",
  resolved: "text-primary bg-primary/10",
};

/**
 * المخالفات والإيقاف — عرض إداري فقط (RLS: fraud.view). التسجيل
 * التلقائي (إلغاء الطلبات المتكرر) يظهر هنا تلقائيًا بلا أي تدخّل —
 * التسجيل اليدوي لبقية الأنواع عبر النموذج أسفل الصفحة.
 */
export default async function FraudPage() {
  const context = await getAdminContext();
  if (!context?.hasCapability("fraud.view")) redirect("/dashboard");

  const canManage = context.hasCapability("fraud.manage");
  const supabase = await createClient();

  const { data: cases } = await supabase
    .from("fraud_cases")
    .select(
      "id, user_id, role, violation_type, violation_count, severity, reason, status, admin_notes, created_at, updated_at, users(full_name, phone, is_suspended)",
    )
    .order("updated_at", { ascending: false });

  const items = (cases ?? []) as unknown as FraudCase[];
  const suspendedUserIds = new Set(
    items.filter((c) => c.users?.is_suspended).map((c) => c.user_id),
  );

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">المخالفات والإيقاف</h1>
      <p className="text-sm text-black/60 mb-6">
        إلغاء الطلبات المتكرر من طرف العميل يُرصَد تلقائيًا. بقية الأنواع
        تُسجَّل يدويًا هنا. عند بلوغ مجموع مخالفات مستخدم حدّ الإيقاف
        (قابل للتعديل من الإعدادات) يُوقَف حسابه تلقائيًا — يُمنَع من
        إنشاء طلبات جديدة أو استلامها كموصّل.
      </p>

      {canManage && (
        <div className="rounded-xl border border-border bg-card p-5 mb-6">
          <p className="font-semibold mb-3">تسجيل مخالفة يدويًا</p>
          <LogViolationForm />
        </div>
      )}

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد مخالفات مسجَّلة بعد.</p>
      ) : (
        <div className="grid gap-3">
          {items.map((c) => (
            <div
              key={c.id}
              className="rounded-xl border border-border bg-card p-4"
            >
              <div className="flex items-start justify-between gap-3 flex-wrap">
                <div className="min-w-0">
                  <p className="font-semibold">
                    {c.users?.full_name || "مستخدم"}{" "}
                    <span className="text-black/50 font-normal text-sm">
                      ({FRAUD_ROLE_LABELS[c.role]}
                      {c.users?.phone ? ` — ${c.users.phone}` : ""})
                    </span>
                  </p>
                  <p className="text-sm text-black/70 mt-1">
                    {c.violation_type} — {c.violation_count} مرّة
                  </p>
                  {c.reason && (
                    <p className="text-xs text-black/50 mt-0.5">{c.reason}</p>
                  )}
                  <p className="text-xs text-black/40 mt-1">
                    آخر تحديث: {new Date(c.updated_at).toLocaleString("ar-DZ")}
                  </p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <span
                    className={`rounded-full px-3 py-1 text-xs font-semibold ${
                      STATUS_COLORS[c.status] ?? "text-black/60 bg-black/5"
                    }`}
                  >
                    {FRAUD_STATUS_LABELS[c.status]}
                  </span>
                  {canManage && (
                    <SuspensionToggle
                      userId={c.user_id}
                      isSuspended={suspendedUserIds.has(c.user_id)}
                    />
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
