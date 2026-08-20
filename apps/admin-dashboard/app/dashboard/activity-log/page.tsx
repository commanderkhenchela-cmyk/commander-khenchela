import { createClient } from "@/lib/supabase/server";
import { tableLabel, type ActivityLogEntry } from "@/lib/types";

const ACTION_COLORS: Record<string, string> = {
  إنشاء: "text-primary bg-primary/10",
  تعديل: "text-warning bg-warning/10",
  حذف: "text-error bg-error/10",
};

export default async function ActivityLogPage() {
  const supabase = await createClient();
  const { data: logs } = await supabase
    .from("admin_activity_log")
    .select("id, admin_name, action, table_name, record_id, created_at")
    .order("created_at", { ascending: false })
    .limit(100);

  const items = (logs ?? []) as ActivityLogEntry[];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">سجل النشاطات</h1>
      <p className="text-sm text-black/60 mb-6">
        كل إجراء إداري مؤثر (الموافقة على محل، تعديل الهوية أو التصنيفات أو
        بيانات التواصل...) يُسجَّل هنا تلقائيًا من قاعدة البيانات نفسها —
        لا يمكن تعديل هذا السجل أو حذفه من أي واجهة.
      </p>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد نشاطات مسجَّلة بعد.</p>
      ) : (
        <div className="grid gap-2">
          {items.map((log) => (
            <div
              key={log.id}
              className="rounded-xl border border-border bg-card p-4 flex items-center justify-between gap-4"
            >
              <div className="min-w-0">
                <p className="font-medium truncate">
                  {log.admin_name || "أدمن"}{" "}
                  <span className="text-black/60 font-normal">
                    {log.action} {tableLabel(log.table_name)}
                  </span>
                </p>
                <p className="text-xs text-black/40 mt-0.5">
                  {new Date(log.created_at).toLocaleString("ar-DZ")}
                </p>
              </div>
              <span
                className={`shrink-0 rounded-full px-3 py-1 text-xs font-semibold ${
                  ACTION_COLORS[log.action] ?? "text-black/60 bg-black/5"
                }`}
              >
                {log.action}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
