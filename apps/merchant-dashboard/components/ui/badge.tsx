import type { ReactNode } from "react";

export type BadgeTone = "primary" | "warning" | "error" | "neutral";

const TONE_CLASSES: Record<BadgeTone, string> = {
  primary: "text-primary bg-primary/10",
  warning: "text-warning bg-warning/10",
  error: "text-error bg-error/10",
  neutral: "text-black/60 bg-black/5",
};

/** نفس صيغة "rounded-full px-3 py-1 text-xs font-semibold" + لون حسب
 * الحالة — كانت مطبَّقة يدويًا وبشكل متعارض بين orders/page.tsx
 * (StatusBadge) وorders/[id]/page.tsx (نص بلا لون إطلاقًا). الآن أصناف
 * موحّدة؛ خريطة الحالة→اللون نفسها منتقلة إلى lib/order-status.ts. */
export function Badge({
  tone = "neutral",
  className = "",
  children,
}: {
  tone?: BadgeTone;
  className?: string;
  children: ReactNode;
}) {
  return (
    <span className={`inline-block rounded-full px-3 py-1 text-xs font-semibold ${TONE_CLASSES[tone]} ${className}`}>
      {children}
    </span>
  );
}
