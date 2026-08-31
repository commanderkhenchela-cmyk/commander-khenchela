/** لبنة تحميل بصرية بسيطة — تُستخدَم في notifications-list.tsx بدل نص
 * "جارِ التحميل..." العادي الذي كان مختلفًا عن شكل التحميل في بقية
 * التطبيق (app/loading.tsx spinner للصفحات المجلوبة من السيرفر). */
export function Skeleton({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded-lg bg-black/5 ${className}`} />;
}
