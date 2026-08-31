import type { ReactNode } from "react";

/** حالة فارغة موحّدة — كانت سطر <p> عاديًا بصياغة/شفافية مختلفة في كل
 * صفحة (orders/page.tsx, products/page.tsx, wallet/page.tsx,
 * notifications-list.tsx). لا تغيير في متى تُعرَض (نفس شرط .length===0
 * في كل مكان)، فقط شكل موحّد وأوضح. */
export function EmptyState({
  icon,
  title,
  description,
}: {
  icon?: ReactNode;
  title: string;
  description?: string;
}) {
  return (
    <div className="flex flex-col items-center text-center gap-2 rounded-xl border border-dashed border-border py-10 px-6">
      {icon && <div className="text-black/30">{icon}</div>}
      <p className="text-black/60 font-medium">{title}</p>
      {description && <p className="text-sm text-black/40">{description}</p>}
    </div>
  );
}
