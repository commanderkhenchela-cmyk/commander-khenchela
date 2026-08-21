"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { createClient } from "@/lib/supabase/client";
import type { Merchant } from "@/lib/types";

const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 ميغابايت — نفس حد صور المنتجات

type ImageKind = "logo" | "cover";

/// رفع شعار المحل وصورة الغلاف — هما ما يظهر للعميل بدل الأيقونة الرمزية
/// العامة في كل بطاقة محل (الصفحة الرئيسية، البحث، قائمة التصنيف). كلاهما
/// اختياري: بدون رفعهما يبقى شكل البطاقات الحالي (أيقونة) كما هو تمامًا.
export default function StoreImagesForm({ merchant }: { merchant: Merchant }) {
  const router = useRouter();
  const [logoUrl, setLogoUrl] = useState(merchant.logo_url);
  const [coverUrl, setCoverUrl] = useState(merchant.cover_url);
  const [uploading, setUploading] = useState<ImageKind | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleUpload(kind: ImageKind, file: File) {
    if (file.size > MAX_IMAGE_BYTES) {
      setError("حجم الصورة كبير جدًا (الحد الأقصى 5 ميغابايت).");
      return;
    }

    setError(null);
    setUploading(kind);

    const supabase = createClient();
    const ext = file.name.split(".").pop() ?? "jpg";
    const path = `${merchant.id}/${kind}-${Date.now()}.${ext}`;

    const { error: uploadError } = await supabase.storage
      .from("merchant-images")
      .upload(path, file, { upsert: true });

    if (uploadError) {
      setError("تعذّر رفع الصورة.");
      setUploading(null);
      return;
    }

    const {
      data: { publicUrl },
    } = supabase.storage.from("merchant-images").getPublicUrl(path);

    const column = kind === "logo" ? "logo_url" : "cover_url";
    const { error: updateError } = await supabase
      .from("merchants")
      .update({ [column]: publicUrl })
      .eq("id", merchant.id);

    if (updateError) {
      setError("رُفعت الصورة لكن تعذّر حفظها. حاول مجددًا.");
      setUploading(null);
      return;
    }

    if (kind === "logo") setLogoUrl(publicUrl);
    else setCoverUrl(publicUrl);
    setUploading(null);
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-5">
      <div>
        <p className="text-sm font-medium mb-1">شعار المحل</p>
        <p className="text-xs text-black/50 mb-2">
          يظهر داخل بطاقات محلك في التطبيق بدل الأيقونة الافتراضية. مربّع،
          الأفضل خلفية بسيطة وواضحة.
        </p>
        <div className="flex items-center gap-3">
          <div className="w-16 h-16 rounded-xl overflow-hidden border border-border bg-background shrink-0 relative">
            {logoUrl && (
              <Image
                src={logoUrl}
                alt="شعار المحل"
                fill
                unoptimized
                className="object-cover"
              />
            )}
          </div>
          <input
            type="file"
            accept="image/*"
            disabled={uploading !== null}
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) handleUpload("logo", file);
            }}
            className="text-sm"
          />
        </div>
      </div>

      <div>
        <p className="text-sm font-medium mb-1">صورة الغلاف</p>
        <p className="text-xs text-black/50 mb-2">
          تظهر أعلى صفحة محلك عند فتح العميل له. مستطيلة عريضة.
        </p>
        <div className="w-full aspect-[16/6] rounded-xl overflow-hidden border border-border bg-background relative mb-2">
          {coverUrl && (
            <Image
              src={coverUrl}
              alt="صورة الغلاف"
              fill
              unoptimized
              className="object-cover"
            />
          )}
        </div>
        <input
          type="file"
          accept="image/*"
          disabled={uploading !== null}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) handleUpload("cover", file);
          }}
          className="text-sm"
        />
      </div>

      {uploading && (
        <p className="text-sm text-black/60">جارٍ رفع الصورة...</p>
      )}
      {error && <p className="text-error text-sm">{error}</p>}
    </div>
  );
}
