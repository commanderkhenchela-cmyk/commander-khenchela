"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export default function SignupPage() {
  const router = useRouter();
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [needsConfirmation, setNeedsConfirmation] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    if (password.length < 6) {
      setError("كلمة المرور يجب أن تكون 6 أحرف على الأقل.");
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { role: "merchant", full_name: fullName, phone },
      },
    });

    if (error) {
      setError(
        error.message === "User already registered"
          ? "هذا البريد الإلكتروني مسجَّل مسبقًا. سجّل الدخول بدلًا من ذلك."
          : "تعذّر إنشاء الحساب. حاول مرة أخرى.",
      );
      setLoading(false);
      return;
    }

    // إذا كان تأكيد البريد الإلكتروني مفعّلًا في إعدادات Supabase،
    // لن تكون هناك جلسة (session) فورية بعد التسجيل.
    if (!data.session) {
      setNeedsConfirmation(true);
      setLoading(false);
      return;
    }

    router.replace("/onboarding");
    router.refresh();
  }

  if (needsConfirmation) {
    return (
      <main className="flex flex-1 items-center justify-center p-6">
        <div className="w-full max-w-sm rounded-2xl bg-card border border-border p-8 shadow-sm text-center">
          <h1 className="text-xl font-bold mb-3">تحقق من بريدك الإلكتروني</h1>
          <p className="text-black/70">
            أرسلنا رابط تأكيد إلى بريدك الإلكتروني. افتحه لتفعيل حسابك، ثم عد
            وسجّل الدخول.
          </p>
          <Link
            href="/login"
            className="inline-block mt-6 text-primary font-semibold"
          >
            الذهاب لتسجيل الدخول
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="flex flex-1 items-center justify-center p-6">
      <div className="w-full max-w-sm rounded-2xl bg-card border border-border p-8 shadow-sm">
        <h1 className="text-2xl font-bold text-center mb-1">
          سجّل محلك كتاجر
        </h1>
        <p className="text-center text-sm text-black/60 mb-6">
          Commander Khenchela
        </p>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div>
            <label className="block text-sm font-medium mb-1">
              الاسم الكامل
            </label>
            <input
              type="text"
              required
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">
              رقم الهاتف
            </label>
            <input
              type="tel"
              required
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
              placeholder="0555xxxxxx"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">
              البريد الإلكتروني
            </label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">
              كلمة المرور
            </label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
            />
          </div>

          {error && <p className="text-error text-sm text-center">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-lg bg-primary text-white font-semibold py-3 mt-2 disabled:opacity-60"
          >
            {loading ? "جارٍ الإنشاء..." : "إنشاء الحساب"}
          </button>
        </form>

        <p className="text-center text-sm mt-6">
          لديك حساب بالفعل؟{" "}
          <Link href="/login" className="text-primary font-semibold">
            سجّل الدخول
          </Link>
        </p>
      </div>
    </main>
  );
}
