"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

/**
 * تبديل يدوي لحالة "مفتوح/مغلق" — نفس نمط الكتابة المباشرة على merchants
 * المستخدَم فعلًا في settings-form.tsx/location-form.tsx/
 * store-images-form.tsx (update بسيط عبر RLS merchants_update_own
 * الموجودة أصلًا، بلا أي RPC جديد). props بسيطة قابلة للتسلسل عن قصد
 * (merchantId: string, initialIsOpen: boolean) — لا مراجع دوال/مكوّنات،
 * تفاديًا لخطأ RSC serialization نفسه الذي ظهر سابقًا في هذه الجلسة عند
 * تمرير أيقونات كـ prop من Server إلى Client Component.
 *
 * الألوان بنفس أصناف tone الموجودة في components/ui/badge.tsx
 * (primary=أخضر، error=أحمر) — نفس لغة الألوان في كل التطبيق، فقط بحجم
 * أوضح (زر لا شارة صغيرة) لأنه عنصر تحكّم فعلي وليس مجرد عرض حالة.
 */
export function StoreStatusToggle({
  merchantId,
  initialIsOpen,
}: {
  merchantId: string;
  initialIsOpen: boolean;
}) {
  const router = useRouter();
  const [isOpen, setIsOpen] = useState(initialIsOpen);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function toggle() {
    const next = !isOpen;
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error: updateError } = await supabase
      .from("merchants")
      .update({ is_open: next })
      .eq("id", merchantId);

    setLoading(false);

    if (updateError) {
      // لا نغيّر الحالة المعروضة عند الفشل — تبقى الواجهة مطابقة لما هو
      // محفوظ فعلًا في قاعدة البيانات، لا لما ظننّا أننا حفظناه.
      setError("تعذّر تحديث حالة المحل. حاول مرة أخرى.");
      return;
    }

    setIsOpen(next);
    router.refresh();
  }

  return (
    <div>
      <button
        type="button"
        onClick={toggle}
        disabled={loading}
        aria-label={isOpen ? "المحل مفتوح — اضغط لإغلاقه" : "المحل مغلق — اضغط لفتحه"}
        className={`w-full flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-semibold transition-colors disabled:opacity-60 outline-none focus-visible:ring-2 focus-visible:ring-offset-2 ${
          isOpen
            ? "text-primary bg-primary/10 hover:bg-primary/15 focus-visible:ring-primary/40"
            : "text-error bg-error/10 hover:bg-error/15 focus-visible:ring-error/40"
        }`}
      >
        {loading ? (
          <span className="h-2.5 w-2.5 rounded-full border-2 border-current border-t-transparent animate-spin" />
        ) : (
          <span className="h-2.5 w-2.5 rounded-full bg-current shrink-0" />
        )}
        {isOpen ? "مفتوح" : "مغلق"}
      </button>
      {error && <p className="text-error text-xs mt-1.5 text-center">{error}</p>}
    </div>
  );
}
