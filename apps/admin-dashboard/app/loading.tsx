/**
 * Suspense fallback عام لكل مسارات التطبيق (Next.js يعرضه تلقائيًا أثناء
 * تحميل أي صفحة async، ما لم يوجد loading.tsx أقرب داخل نفس الشجرة).
 * بدونه، التنقّل البطيء (اتصال ضعيف مثلاً) كان يعرض إطارًا فارغًا تمامًا.
 */
export default function Loading() {
  return (
    <div className="flex min-h-[50vh] items-center justify-center">
      <div
        className="h-8 w-8 animate-spin rounded-full border-2 border-border border-t-primary"
        role="status"
        aria-label="جارٍ التحميل"
      />
    </div>
  );
}
