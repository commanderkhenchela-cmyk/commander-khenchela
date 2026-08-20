"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { Merchant } from "@/lib/types";

export default function LocationForm({ merchant }: { merchant: Merchant }) {
  const router = useRouter();
  const [latitude, setLatitude] = useState(merchant.latitude);
  const [longitude, setLongitude] = useState(merchant.longitude);
  const [locating, setLocating] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  function captureLocation() {
    if (!("geolocation" in navigator)) {
      setError("متصفحك لا يدعم تحديد الموقع.");
      return;
    }

    setError(null);
    setSaved(false);
    setLocating(true);

    navigator.geolocation.getCurrentPosition(
      (position) => {
        setLatitude(position.coords.latitude);
        setLongitude(position.coords.longitude);
        setLocating(false);
      },
      () => {
        setError(
          "تعذّر الحصول على موقعك — تأكد من السماح بالوصول للموقع من إعدادات المتصفح.",
        );
        setLocating(false);
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  }

  async function saveLocation() {
    if (latitude == null || longitude == null) return;

    setSaving(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase
      .from("merchants")
      .update({ latitude, longitude })
      .eq("id", merchant.id);

    if (error) {
      setError("تعذّر حفظ الموقع.");
      setSaving(false);
      return;
    }

    setSaved(true);
    setSaving(false);
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-black/60">
        يُستخدم لعرض محلك في قسم &quot;الأقرب إليك&quot; للعميل. اضغط الزر
        وأنت داخل المحل فعليًا لأدق نتيجة.
      </p>

      <button
        type="button"
        onClick={captureLocation}
        disabled={locating}
        className="rounded-lg border border-primary text-primary font-semibold py-2.5 disabled:opacity-60"
      >
        {locating ? "جارٍ تحديد موقعك..." : "استخدم موقعي الحالي"}
      </button>

      {latitude != null && longitude != null && (
        <div className="rounded-lg border border-border bg-card p-3 text-sm flex items-center justify-between gap-2">
          <span className="text-black/60">
            {latitude.toFixed(5)}, {longitude.toFixed(5)}
          </span>
          <a
            href={`https://www.google.com/maps?q=${latitude},${longitude}`}
            target="_blank"
            rel="noopener noreferrer"
            className="text-primary font-medium shrink-0"
          >
            تحقّق على الخريطة
          </a>
        </div>
      )}

      {error && <p className="text-error text-sm">{error}</p>}
      {saved && <p className="text-primary text-sm">تم حفظ الموقع بنجاح.</p>}

      <button
        type="button"
        onClick={saveLocation}
        disabled={saving || latitude == null || longitude == null}
        className="w-full rounded-lg bg-primary text-white font-semibold py-3 disabled:opacity-60"
      >
        {saving ? "جارٍ الحفظ..." : "حفظ الموقع"}
      </button>
    </div>
  );
}
