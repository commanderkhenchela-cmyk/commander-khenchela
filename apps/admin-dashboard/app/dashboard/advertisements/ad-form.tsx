"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { Advertisement } from "@/lib/types";

const MAX_VIDEO_BYTES = 50 * 1024 * 1024; // 50 ميغابايت — نفس حد الـ Storage bucket
const MAX_THUMB_BYTES = 3 * 1024 * 1024; // 3 ميغابايت

export default function AdForm({ ad }: { ad?: Advertisement }) {
  const router = useRouter();
  const isEditing = Boolean(ad);

  const [title, setTitle] = useState(ad?.title ?? "");
  const [description, setDescription] = useState(ad?.description ?? "");
  const [advertiserName, setAdvertiserName] = useState(
    ad?.advertiser_name ?? "",
  );
  const [linkUrl, setLinkUrl] = useState(ad?.link_url ?? "");
  const [startDate, setStartDate] = useState(ad?.start_date ?? "");
  const [endDate, setEndDate] = useState(ad?.end_date ?? "");
  const [sortOrder, setSortOrder] = useState(ad?.sort_order ?? 0);
  const [isActive, setIsActive] = useState(ad?.is_active ?? true);

  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [thumbFile, setThumbFile] = useState<File | null>(null);
  const [thumbPreview, setThumbPreview] = useState<string | null>(
    ad?.thumbnail_url ?? null,
  );

  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<string | null>(null);

  function handleVideoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > MAX_VIDEO_BYTES) {
      setError("حجم الفيديو كبير جدًا (الحد الأقصى 50 ميغابايت).");
      return;
    }
    setError(null);
    setVideoFile(file);
  }

  function handleThumbChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > MAX_THUMB_BYTES) {
      setError("حجم الصورة كبير جدًا (الحد الأقصى 3 ميغابايت).");
      return;
    }
    setError(null);
    setThumbFile(file);
    setThumbPreview(URL.createObjectURL(file));
  }

  async function uploadToAdMedia(file: File, prefix: string) {
    const supabase = createClient();
    const ext = file.name.split(".").pop() ?? "bin";
    const path = `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;

    const { error: uploadError } = await supabase.storage
      .from("ad-media")
      .upload(path, file);

    if (uploadError) throw uploadError;

    const {
      data: { publicUrl },
    } = supabase.storage.from("ad-media").getPublicUrl(path);
    return publicUrl;
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    if (!isEditing && !videoFile) {
      setError("فيديو الإعلان مطلوب.");
      return;
    }
    if (
      startDate &&
      endDate &&
      new Date(startDate) > new Date(endDate)
    ) {
      setError("تاريخ البداية يجب أن يكون قبل تاريخ النهاية.");
      return;
    }

    setLoading(true);
    setError(null);
    setSaved(false);

    try {
      let videoUrl = ad?.video_url ?? "";
      let thumbnailUrl = ad?.thumbnail_url ?? null;

      if (videoFile) {
        setUploadProgress("جارٍ رفع الفيديو...");
        videoUrl = await uploadToAdMedia(videoFile, "video");
      }
      if (thumbFile) {
        setUploadProgress("جارٍ رفع الصورة المصغّرة...");
        thumbnailUrl = await uploadToAdMedia(thumbFile, "thumb");
      }
      setUploadProgress(null);

      const payload = {
        title,
        description: description || null,
        advertiser_name: advertiserName,
        video_url: videoUrl,
        thumbnail_url: thumbnailUrl,
        link_url: linkUrl || null,
        start_date: startDate || null,
        end_date: endDate || null,
        sort_order: sortOrder,
        is_active: isActive,
      };

      const supabase = createClient();
      const { error: dbError } = isEditing
        ? await supabase
            .from("advertisements")
            .update(payload)
            .eq("id", ad!.id)
        : await supabase.from("advertisements").insert(payload);

      if (dbError) throw dbError;

      setSaved(true);
      setVideoFile(null);
      setThumbFile(null);
      router.refresh();
      if (!isEditing) router.push("/dashboard/advertisements");
    } catch {
      setError("تعذّر حفظ الإعلان. تحقق من الملفات والحقول ثم أعد المحاولة.");
    } finally {
      setLoading(false);
      setUploadProgress(null);
    }
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="flex flex-col gap-5 rounded-xl border border-border bg-card p-5"
    >
      <div>
        <label className="block text-sm font-medium mb-1">عنوان الإعلان</label>
        <input
          type="text"
          required
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">اسم المعلن/المتجر</label>
        <input
          type="text"
          required
          value={advertiserName}
          onChange={(e) => setAdvertiserName(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">الوصف (اختياري)</label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={2}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary resize-none"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          فيديو الإعلان {isEditing && "(اتركه فارغًا للإبقاء على الحالي)"}
        </label>
        <input
          type="file"
          accept="video/*"
          onChange={handleVideoChange}
          className="w-full text-sm"
        />
        {videoFile && (
          <p className="text-xs text-primary mt-1">تم اختيار: {videoFile.name}</p>
        )}
        <p className="text-xs text-black/50 mt-1">
          MP4 يُفضَّل، حد أقصى 50 ميغابايت — فيديو قصير (15-30 ثانية) أفضل للأداء
        </p>
      </div>

      <div>
        <label className="block text-sm font-medium mb-2">
          الصورة المصغّرة (تظهر قبل تشغيل الفيديو)
        </label>
        <div className="flex items-center gap-4">
          <div className="w-20 h-20 rounded-xl overflow-hidden border border-border bg-background flex items-center justify-center shrink-0">
            {thumbPreview ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={thumbPreview}
                alt="معاينة"
                className="w-full h-full object-cover"
              />
            ) : (
              <span className="text-2xl">🎬</span>
            )}
          </div>
          <input
            type="file"
            accept="image/*"
            onChange={handleThumbChange}
            className="flex-1 text-sm"
          />
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          رابط الإعلان (اختياري — يفتح عند الضغط على زر الدعوة)
        </label>
        <input
          type="url"
          value={linkUrl}
          onChange={(e) => setLinkUrl(e.target.value)}
          placeholder="https://..."
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium mb-1">تاريخ البداية</label>
          <input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">تاريخ النهاية</label>
          <input
            type="date"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
          />
        </div>
      </div>
      <p className="text-xs text-black/50 -mt-3">
        اتركهما فارغَين لعرض الإعلان بلا سقف زمني (طالما مفعَّل)
      </p>

      <div className="grid grid-cols-2 gap-4 items-end">
        <div>
          <label className="block text-sm font-medium mb-1">
            ترتيب الأولوية (الأصغر يظهر أولًا)
          </label>
          <input
            type="number"
            value={sortOrder}
            onChange={(e) => setSortOrder(Number(e.target.value))}
            className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
          />
        </div>
        <label className="flex items-center gap-2 text-sm font-medium pb-2.5">
          <input
            type="checkbox"
            checked={isActive}
            onChange={(e) => setIsActive(e.target.checked)}
          />
          مفعَّل
        </label>
      </div>

      {uploadProgress && (
        <p className="text-sm text-black/60">{uploadProgress}</p>
      )}
      {error && <p className="text-error text-sm">{error}</p>}
      {saved && !error && (
        <p className="text-primary text-sm">تم الحفظ بنجاح.</p>
      )}

      <button
        type="submit"
        disabled={loading}
        className="rounded-lg bg-primary text-white font-semibold py-3 disabled:opacity-60"
      >
        {loading
          ? "جارٍ الحفظ..."
          : isEditing
            ? "حفظ التعديلات"
            : "إنشاء الإعلان"}
      </button>
    </form>
  );
}
