import type { HTMLAttributes } from "react";

/** نفس صيغة "rounded-xl border border-border bg-card p-4/p-5" التي كانت
 * منسوخة يدويًا في كل صفحة تقريبًا (orders, products, wallet, settings,
 * hours...) — لا تغيير في المظهر النهائي، فقط تعريف واحد بدل التكرار. */
export function Card({
  className = "",
  padding = "p-5",
  ...rest
}: HTMLAttributes<HTMLDivElement> & { padding?: string }) {
  return (
    <div
      className={`rounded-xl border border-border bg-card ${padding} ${className}`}
      {...rest}
    />
  );
}
