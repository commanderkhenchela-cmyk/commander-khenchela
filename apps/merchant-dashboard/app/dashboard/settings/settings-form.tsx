"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { Merchant } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { FieldError, FieldSuccess, Input, Label } from "@/components/ui/input";

export default function SettingsForm({ merchant }: { merchant: Merchant }) {
  const router = useRouter();
  const [storeName, setStoreName] = useState(merchant.store_name);
  const [addressText, setAddressText] = useState(merchant.address_text ?? "");
  const [phone, setPhone] = useState(merchant.phone ?? "");
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    const supabase = createClient();
    const { error } = await supabase
      .from("merchants")
      .update({ store_name: storeName, address_text: addressText, phone })
      .eq("id", merchant.id);

    if (error) {
      setError("تعذّر حفظ التعديلات.");
      setLoading(false);
      return;
    }

    setSaved(true);
    setLoading(false);
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
        />
      </div>

      <div>
        <Label>العنوان بالتفصيل</Label>
        <Input
          type="text"
          required
          value={addressText}
          onChange={(e) => setAddressText(e.target.value)}
        />
      </div>

      <div>
        <Label>هاتف المحل</Label>
        <Input
          type="tel"
          required
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
        />
      </div>

      <FieldError>{error}</FieldError>
      <FieldSuccess>{saved && "تم الحفظ بنجاح."}</FieldSuccess>

      <Button type="submit" disabled={loading} className="w-full mt-2">
        {loading ? "جارٍ الحفظ..." : "حفظ التعديلات"}
      </Button>
    </form>
  );
}
