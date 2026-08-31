"use client";

import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { ReactNode } from "react";

export default function LogoutButton({
  className,
  children,
}: {
  className?: string;
  /** محتوى الزر — اختياري، بديل بصري بحت لنفس زر "تسجيل الخروج"
   * (مثلًا نص + أيقونة). القيمة الافتراضية نفس النص الأصلي. */
  children?: ReactNode;
}) {
  const router = useRouter();

  async function handleLogout() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.replace("/login");
    router.refresh();
  }

  return (
    <button onClick={handleLogout} className={className}>
      {children ?? "تسجيل الخروج"}
    </button>
  );
}
