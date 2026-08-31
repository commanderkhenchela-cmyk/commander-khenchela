"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { AuthCard } from "@/components/ui/auth-card";
import { Button } from "@/components/ui/button";
import { FieldError, Input, Label } from "@/components/ui/input";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setError(
        error.message === "Invalid login credentials"
          ? "البريد الإلكتروني أو كلمة المرور غير صحيحة."
          : "تعذّر تسجيل الدخول. حاول مرة أخرى.",
      );
      setLoading(false);
      return;
    }

    router.replace("/");
    router.refresh();
  }

  return (
    <AuthCard>
      <h1 className="text-2xl font-bold text-center mb-1">
        لوحة تحكم التاجر
      </h1>
      <p className="text-center text-sm text-black/60 mb-6">
        Commander Khenchela
      </p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <Label>البريد الإلكتروني</Label>
          <Input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="example@email.com"
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
          {loading ? "جارٍ الدخول..." : "تسجيل الدخول"}
        </Button>
      </form>

      <p className="text-center text-sm mt-6">
        ليس لديك حساب تاجر؟{" "}
        <Link href="/signup" className="text-primary font-semibold">
          سجّل محلك الآن
        </Link>
      </p>
    </AuthCard>
  );
}
