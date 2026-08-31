"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { KHENCHELA_WILAYA_ID, type Commune } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { FieldError, Input, Label, Select } from "@/components/ui/input";

export default function OnboardingForm({ communes }: { communes: Commune[] }) {
  const router = useRouter();
  const [storeName, setStoreName] = useState("");
  const [communeId, setCommuneId] = useState<string>(
    communes[0] ? String(communes[0].id) : "",
  );
  const [addressText, setAddressText] = useState("");
  const [phone, setPhone] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      router.replace("/login");
      return;
    }

    const { error } = await supabase.from("merchants").insert({
      owner_user_id: user.id,
      store_name: storeName,
      wilaya_id: KHENCHELA_WILAYA_ID,
      commune_id: Number(communeId),
      address_text: addressText,
      phone,
      status: "pending",
    });

    if (error) {
      // 23505 = unique_violation على قيد merchants_owner_user_id_key — يعني
      // أن هذا المستخدم يملك محلًا بالفعل (حالة نادرة: كان يقف على هذه
      // الصفحة قبل أن يلحق السياق تحديث حالته). التوجيه لـ "/" يرسله
      // تلقائيًا لمكانه الصحيح (قيد المراجعة/مرفوض/لوحة التحكم) بدل رسالة
      // خطأ عامة لا تشرح له شيئًا.
      if (error.code === "23505") {
        router.replace("/");
        router.refresh();
        return;
      }

      setError("تعذّر إنشاء المحل. حاول مرة أخرى.");
      setLoading(false);
      return;
    }

    router.replace("/pending");
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div>
        <Label>اسم المحل</Label>
        <Input
          type="text"
          required
          value={storeName}
          onChange={(e) => setStoreName(e.target.value)}
          placeholder="مثال: بقالة النور"
        />
      </div>

      <div>
        <Label>البلدية</Label>
        <Select
          required
          value={communeId}
          onChange={(e) => setCommuneId(e.target.value)}
        >
          {communes.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </Select>
      </div>

      <div>
        <Label>العنوان بالتفصيل</Label>
        <Input
          type="text"
          required
          value={addressText}
          onChange={(e) => setAddressText(e.target.value)}
          placeholder="الحي، الشارع، رقم المحل..."
        />
      </div>

      <div>
        <Label>هاتف المحل (يظهر للعملاء عند الحاجة)</Label>
        <Input
          type="tel"
          required
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="0555xxxxxx"
        />
      </div>

      <FieldError className="text-center">{error}</FieldError>

      <Button type="submit" disabled={loading} className="w-full mt-2">
        {loading ? "جارٍ الإرسال..." : "إرسال للمراجعة"}
      </Button>
    </form>
  );
}
