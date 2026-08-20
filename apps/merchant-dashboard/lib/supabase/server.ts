import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/**
 * عميل Supabase الذي يعمل على السيرفر (Server Components / Actions).
 * يقرأ ويكتب الجلسة (session) عبر الـ cookies، ويستخدم فقط الـ publishable key.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // يحدث عند استدعاء setAll من Server Component بدون Middleware —
            // يمكن تجاهله لأن الـ Middleware يتكفّل بتحديث الجلسة.
          }
        },
      },
    },
  );
}
