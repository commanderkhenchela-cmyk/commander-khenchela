"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { createClient } from "@/lib/supabase/client";
import type { AppBranding } from "@/lib/types";

const MAX_LOGO_BYTES = 2 * 1024 * 1024; // 2 ميغابايت — الشعار ملف صغير

export default function BrandingForm({ branding }: { branding: AppBranding }) {
  const router = useRouter();

  const [appName, setAppName] = useState(branding.app_name);
  const [primaryColor, setPrimaryColor] = useState(branding.primary_color);
  const [errorColor, setErrorColor] = useState(branding.error_color);
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(
    branding.logo_url,
  );
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  function handleLogoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > MAX_LOGO_BYTES) {
      setError("حجم الصورة كبير جدًا (الحد الأقصى 2 ميغابايت).");
      return;
    }

    setError(null);
    setLogoFile(file);
    setPreviewUrl(URL.createObjectURL(file));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    const hexPattern = /^#[0-9a-fA-F]{6}$/;
    if (!hexPattern.test(primaryColor) || !hexPattern.test(errorColor)) {
      setError('الألوان يجب أن تكون بصيغة "#1B7A3D" (6 خانات بعد #).');
      setLoading(false);
      return;
    }

    const supabase = createClient();
    let logoUrl = branding.logo_url;

    if (logoFile) {
      const ext = logoFile.name.split(".").pop() ?? "png";
      const path = `logo-${Date.now()}.${ext}`;

      const { error: uploadError } = await supabase.storage
        .from("branding-assets")
        .upload(path, logoFile, { upsert: true });

      if (uploadError) {
        setError("تعذّر رفع الشعار.");
        setLoading(false);
        return;
      }

      const {
        data: { publicUrl },
      } = supabase.storage.from("branding-assets").getPublicUrl(path);
      logoUrl = publicUrl;
    }

    const { error: updateError } = await supabase
      .from("app_branding")
      .update({
        app_name: appName,
        primary_color: primaryColor,
        error_color: errorColor,
        logo_url: logoUrl,
      })
      .eq("id", "default");

    if (updateError) {
      setError("تعذّر حفظ التعديلات.");
      setLoading(false);
      return;
    }

    setSaved(true);
    setLogoFile(null);
    router.refresh();
    setLoading(false);
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="flex flex-col gap-5 rounded-xl border border-border bg-card p-5"
    >
      <div>
        <label className="block text-sm font-medium mb-2">شعار التطبيق</label>
        <div className="flex items-center gap-4">
          <div className="w-20 h-20 rounded-2xl overflow-hidden border border-border bg-background flex items-center justify-center shrink-0">
            {previewUrl ? (
              <Image
                src={previewUrl}
                alt="الشعار"
                width={80}
                height={80}
                unoptimized
                className="object-cover w-full h-full"
              />
            ) : (
              <span className="text-3xl">🏪</span>
            )}
          </div>
          <div className="flex-1">
            <input
              type="file"
              accept="image/*"
              onChange={handleLogoChange}
              className="w-full text-sm"
            />
            <p className="text-xs text-black/50 mt-1">
              مربّعة الشكل يُفضَّل (مثلًا 512×512)، خلفية شفافة إن أمكن
            </p>
          </div>
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">اسم التطبيق</label>
        <input
          type="text"
          required
          value={appName}
          onChange={(e) => setAppName(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          اللون الأساسي
        </label>
        <div className="flex items-center gap-3">
          <input
            type="color"
            value={primaryColor}
            onChange={(e) => setPrimaryColor(e.target.value)}
            className="w-12 h-10 rounded-lg border border-border cursor-pointer"
          />
          <input
            type="text"
            value={primaryColor}
            onChange={(e) => setPrimaryColor(e.target.value)}
            className="flex-1 rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary font-mono text-sm"
            placeholder="#1B7A3D"
          />
        </div>
        <p className="text-xs text-black/50 mt-1">
          يُستخدم لكل الأزرار، الروابط، والعناصر البارزة في تطبيق الزبون
        </p>
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          لون التنبيهات والأخطاء
        </label>
        <div className="flex items-center gap-3">
          <input
            type="color"
            value={errorColor}
            onChange={(e) => setErrorColor(e.target.value)}
            className="w-12 h-10 rounded-lg border border-border cursor-pointer"
          />
          <input
            type="text"
            value={errorColor}
            onChange={(e) => setErrorColor(e.target.value)}
            className="flex-1 rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary font-mono text-sm"
            placeholder="#B3261E"
          />
        </div>
        <p className="text-xs text-black/50 mt-1">
          يُستخدم لرسائل الخطأ وزر &quot;إلغاء الطلب&quot; ونحوها
        </p>
      </div>

      {error && <p className="text-error text-sm">{error}</p>}
      {saved && !error && (
        <p className="text-primary text-sm">
          تم الحفظ — سيظهر التغيير في تطبيق الزبون عند فتحه من جديد.
        </p>
      )}

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
