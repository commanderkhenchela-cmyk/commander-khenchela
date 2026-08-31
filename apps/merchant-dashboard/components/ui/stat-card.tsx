/** نفس StatCard المحلية غير المصدَّرة التي كانت داخل dashboard/page.tsx
 * فقط — لا تغيير في التصميم، فقط نقلها إلى ملف قابل لإعادة الاستخدام. */
export function StatCard({
  label,
  value,
  highlight,
}: {
  label: string;
  value: number;
  highlight?: boolean;
}) {
  return (
    <div
      className={`rounded-2xl border p-5 ${
        highlight ? "border-primary bg-primary/5" : "border-border bg-card"
      }`}
    >
      <p className="text-3xl font-bold">{value}</p>
      <p className="text-sm text-black/60 mt-1">{label}</p>
    </div>
  );
}
