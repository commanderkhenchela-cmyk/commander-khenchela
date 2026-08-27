import { createClient } from "@/lib/supabase/server";
import { tableLabel, type ActivityLogEntry } from "@/lib/types";

const ACTION_COLORS: Record<string, string> = {
  إنشاء: "text-primary bg-primary/10",
  تعديل: "text-warning bg-warning/10",
  حذف: "text-error bg-error/10",
};

/**
 * سجل النشاطات الخاص بسجل واحد بعينه (محل/موصّل/طلب...) — امتداد لعرض
 * سجل النشاطات العام (dashboard/activity-log) لكن مفلترًا بـ
 * table_name + record_id، بدل بناء نظام Audit موازٍ منفصل لكل صفحة
 * تفاصيل. يُستخدَم داخل صفحات merchants/[id]، drivers/[id]، orders/[id].
 *
 * ملاحظة صدق مهمة: هذا يعرض فقط ما كتبه Trigger فعليًا. لسجل orders
 * تحديدًا، الـ Trigger (log_orders_admin_activity) أُضيف حديثًا في نفس
 * هذه المرحلة — أي طلب أُنشئ أو عُدِّل قبل تطبيق هذا الـ migration على
 * قاعدة البيانات الحية لن يظهر له أي نشاط سابق هنا، وهذا متوقَّع وليس
 * خطأ. كذلك: يسجَّل فقط تعديلات الأدمن (role=admin) — إجراءات
 * manager/ads_manager لا تُسجَّل هنا اليوم (سلوك قائم من قبل، لم يتغيّر).
 */
export default async function EntityActivityLog({
  tableName,
  recordId,
}: {
  tableName: string;
  recordId: string;
}) {
  const supabase = await createClient();
  const { data: logs } = await supabase
    .from("admin_activity_log")
    .select("id, admin_name, action, table_name, record_id, created_at")
    .eq("table_name", tableName)
    .eq("record_id", recordId)
    .order("created_at", { ascending: false })
    .limit(20);

  const items = (logs ?? []) as ActivityLogEntry[];

  return (
    <div className="rounded-xl border border-border bg-card p-5">
      <p className="font-semibold mb-3">سجل النشاطات</p>
      {items.length === 0 ? (
        <p className="text-sm text-black/50">
          لا يوجد نشاط إداري مسجَّل على {tableLabel(tableName)} بعد.
        </p>
      ) : (
        <div className="grid gap-2">
          {items.map((log) => (
            <div
              key={log.id}
              className="flex items-center justify-between gap-3 text-sm border-b border-border last:border-b-0 pb-2 last:pb-0"
            >
              <span className="min-w-0 truncate">
                <span className="font-medium">{log.admin_name || "أدمن"}</span>{" "}
                <span
                  className={`inline-block rounded-full px-2 py-0.5 text-xs font-semibold ${
                    ACTION_COLORS[log.action] ?? "text-black/60 bg-black/5"
                  }`}
                >
                  {log.action}
                </span>
              </span>
              <span className="text-xs text-black/40 shrink-0">
                {new Date(log.created_at).toLocaleString("ar-DZ")}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
