"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { Merchant } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { FieldError, FieldSuccess } from "@/components/ui/input";

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

      <Button
        type="button"
        variant="outline"
        onClick={captureLocation}
        disabled={locating}
        className="w-full"
      >
        {locating ? "جارٍ تحديد موقعك..." : "استخدم موقعي الحالي"}
      </Button>

      {latitude != null && longitude != null && (
        <Card padding="p-3" className="text-sm flex items-center justify-between gap-2">
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
        </Card>
      )}

      <FieldError>{error}</FieldError>
      <FieldSuccess>{saved && "تم حفظ الموقع بنجاح."}</FieldSuccess>

      <Button
        type="button"
        onClick={saveLocation}
        disabled={saving || latitude == null || longitude == null}
        className="w-full"
      >
        {saving ? "جارٍ الحفظ..." : "حفظ الموقع"}
      </Button>
    </div>
  );
}
