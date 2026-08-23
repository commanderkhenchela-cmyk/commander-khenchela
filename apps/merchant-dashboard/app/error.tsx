"use client";

import { useEffect } from "react";

/**
 * حدّ أخطاء عام (Error Boundary) لكل مسارات التطبيق — يجب أن يكون Client
 * Component (شرط Next.js). بدونه، أي خطأ غير متوقَّع في صفحة server كان
 * يسقط لصفحة Next الافتراضية غير المصمَّمة، بدل واجهة تحمل هوية التطبيق
 * وخيار إعادة محاولة واضح.
 */
export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("[Error Boundary]", error);
  }, [error]);

  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center gap-4 px-6 text-center">
      <p className="font-semibold text-error">حدث خطأ غير متوقّع.</p>
      <p className="text-sm text-black/60">
        حاول إعادة المحاولة، أو ارجع لاحقًا إذا استمرت المشكلة.
      </p>
      <button
        onClick={reset}
        className="rounded-lg bg-primary px-4 py-2 font-semibold text-white hover:bg-primary-dark"
      >
        إعادة المحاولة
      </button>
    </div>
  );
}
