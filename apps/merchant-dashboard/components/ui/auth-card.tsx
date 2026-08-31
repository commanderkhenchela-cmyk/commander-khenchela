import type { ReactNode } from "react";

/** نفس القالب المتكرّر في login/signup/pending/rejected/onboarding —
 * بطاقة مُتمركزة "w-full max-w-sm rounded-2xl bg-card border p-8
 * shadow-sm". maxWidth مُعطى كـ prop منفصل بدل الاعتماد على ترتيب
 * أصناف Tailwind في className (max-w-sm و max-w-md قد يتعارضان حسب
 * ترتيب توليد CSS لا ترتيب النص في className). */
export function AuthCard({
  children,
  className = "",
  maxWidth = "max-w-sm",
}: {
  children: ReactNode;
  className?: string;
  maxWidth?: string;
}) {
  return (
    <main className="flex flex-1 items-center justify-center p-6">
      <div className={`w-full ${maxWidth} rounded-2xl bg-card border border-border p-8 shadow-sm ${className}`}>
        {children}
      </div>
    </main>
  );
}
