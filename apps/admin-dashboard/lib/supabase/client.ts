import { createBrowserClient } from "@supabase/ssr";

/**
 * عميل Supabase الذي يعمل داخل المتصفح (Client Components).
 * يستخدم فقط الـ publishable key (آمن للعرض العام) — لا يوجد هنا أي مفتاح سري.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}
