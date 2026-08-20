"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { AppContact } from "@/lib/types";

export default function ContactForm({ contact }: { contact: AppContact }) {
  const router = useRouter();

  const [whatsapp, setWhatsapp] = useState(contact.whatsapp_number);
  const [displayPhone, setDisplayPhone] = useState(contact.display_phone);
  const [email, setEmail] = useState(contact.support_email);
  const [facebook, setFacebook] = useState(contact.facebook_url ?? "");
  const [instagram, setInstagram] = useState(contact.instagram_url ?? "");
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    if (!/^\d{9,15}$/.test(whatsapp)) {
      setError(
        "رقم واتساب يجب أن يكون بصيغة دولية بدون + ولا مسافات، مثال: 213555000000",
      );
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { error: updateError } = await supabase
      .from("app_contact")
      .update({
        whatsapp_number: whatsapp,
        display_phone: displayPhone,
        support_email: email,
        facebook_url: facebook || null,
        instagram_url: instagram || null,
      })
      .eq("id", "default");

    if (updateError) {
      setError("تعذّر حفظ التعديلات.");
      setLoading(false);
      return;
    }

    setSaved(true);
    router.refresh();
    setLoading(false);
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="flex flex-col gap-4 rounded-xl border border-border bg-card p-5"
    >
      <div>
        <label className="block text-sm font-medium mb-1">
          رقم واتساب (صيغة دولية بدون +)
        </label>
        <input
          type="text"
          required
          value={whatsapp}
          onChange={(e) => setWhatsapp(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary font-mono text-sm"
          placeholder="213555000000"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          رقم الهاتف (كما يظهر للعميل)
        </label>
        <input
          type="text"
          required
          value={displayPhone}
          onChange={(e) => setDisplayPhone(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
          placeholder="0555 00 00 00"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          البريد الإلكتروني للدعم
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
          رابط فيسبوك (اختياري)
        </label>
        <input
          type="url"
          value={facebook}
          onChange={(e) => setFacebook(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
          placeholder="https://facebook.com/..."
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          رابط إنستغرام (اختياري)
        </label>
        <input
          type="url"
          value={instagram}
          onChange={(e) => setInstagram(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
          placeholder="https://instagram.com/..."
        />
      </div>

      {error && <p className="text-error text-sm">{error}</p>}
      {saved && !error && <p className="text-primary text-sm">تم الحفظ</p>}

      <button
        type="submit"
        disabled={loading}
        className="rounded-lg bg-primary text-white font-semibold py-3 disabled:opacity-60"
      >
        {loading ? "جارٍ الحفظ..." : "حفظ التعديلات"}
      </button>
    </form>
  );
}
