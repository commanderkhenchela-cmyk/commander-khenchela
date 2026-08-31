"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { AuthCard } from "@/components/ui/auth-card";
import { Button } from "@/components/ui/button";
import { FieldError, Input, Label } from "@/components/ui/input";

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
      <AuthCard className="text-center">
        <h1 className="text-xl font-bold mb-3">تحقق من بريدك الإلكتروني</h1>
        <p className="text-black/70">
          أرسلنا رابط تأكيد إلى بريدك الإلكتروني. افتحه لتفعيل حسابك، ثم عد
          وسجّل الدخول.
        </p>
        <Link href="/login" className="inline-block mt-6 text-primary font-semibold">
          الذهاب لتسجيل الدخول
        </Link>
      </AuthCard>
    );
  }

  return (
    <AuthCard>
      <h1 className="text-2xl font-bold text-center mb-1">سجّل محلك كتاجر</h1>
      <p className="text-center text-sm text-black/60 mb-6">
        Commander Khenchela
      </p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <Label>الاسم الكامل</Label>
          <Input
            type="text"
            required
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
          />
        </div>

        <div>
          <Label>رقم الهاتف</Label>
          <Input
            type="tel"
            required
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="0555xxxxxx"
          />
        </div>

        <div>
          <Label>البريد الإلكتروني</Label>
          <Input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>

        <div>
          <Label>كلمة المرور</Label>
          <Input
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </div>

        <FieldError className="text-center">{error}</FieldError>

        <Button type="submit" disabled={loading} className="w-full mt-2">
          {loading ? "جارٍ الإنشاء..." : "إنشاء الحساب"}
        </Button>
      </form>

      <p className="text-center text-sm mt-6">
        لديك حساب بالفعل؟{" "}
        <Link href="/login" className="text-primary font-semibold">
          سجّل الدخول
        </Link>
      </p>
    </AuthCard>
  );
}
