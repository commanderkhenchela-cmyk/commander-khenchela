"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { DeliveryFeeConfig, DeliveryFeeMethod, DeliveryShareType } from "@/lib/types";

export default function DeliveryFeeConfigForm({
  serviceId,
  config,
}: {
  serviceId: string;
  config: DeliveryFeeConfig | null;
}) {
  const router = useRouter();
  const [method, setMethod] = useState<DeliveryFeeMethod>(config?.method ?? "fixed");
  const [fixedAmount, setFixedAmount] = useState(
    config?.fixed_amount != null ? String(config.fixed_amount) : "",
  );
  const [baseAmount, setBaseAmount] = useState(
    config?.distance_base_amount != null ? String(config.distance_base_amount) : "",
  );
  const [perKmAmount, setPerKmAmount] = useState(
    config?.distance_per_km_amount != null ? String(config.distance_per_km_amount) : "",
  );
  const [shareType, setShareType] = useState<DeliveryShareType>(
    config?.driver_share_type ?? "percentage",
  );
  const [shareValue, setShareValue] = useState(String(config?.driver_share_value ?? 0));
  const [enabled, setEnabled] = useState(config?.enabled ?? true);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSaved(false);

    if (method === "fixed" && fixedAmount === "") {
      setError("أدخل السعر الثابت.");
      setLoading(false);
      return;
    }
    if (method === "distance" && (baseAmount === "" || perKmAmount === "")) {
      setError("أدخل السعر الأساسي وسعر الكيلومتر.");
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { error } = await supabase.rpc("admin_upsert_delivery_fee_config", {
      p_service_id: serviceId,
      p_method: method,
      p_fixed_amount: fixedAmount === "" ? null : Number(fixedAmount),
      p_distance_base_amount: baseAmount === "" ? null : Number(baseAmount),
      p_distance_per_km_amount: perKmAmount === "" ? null : Number(perKmAmount),
      p_driver_share_type: shareType,
      p_driver_share_value: Number(shareValue) || 0,
      p_enabled: enabled,
    });

    if (error) {
      setError(error.message || "تعذّر الحفظ.");
      setLoading(false);
      return;
    }

    setSaved(true);
    router.refresh();
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} className="grid gap-3">
      <div className="grid gap-2 sm:grid-cols-2">
        <label className="text-sm">
          <span className="block mb-1 text-black/60">طريقة الحساب</span>
          <select
            value={method}
            onChange={(e) => setMethod(e.target.value as DeliveryFeeMethod)}
            className="w-full rounded-lg border border-border px-3 py-2 outline-none focus:border-primary"
          >
            <option value="fixed">سعر ثابت</option>
            <option value="distance">حسب المسافة</option>
            <option value="zone">حسب البلدية (الجدول أسفل)</option>
          </select>
        </label>
        <label className="text-sm flex items-end gap-2 pb-2">
          <input
            type="checkbox"
            checked={enabled}
            onChange={(e) => setEnabled(e.target.checked)}
          />
          <span>مفعَّل</span>
        </label>
      </div>

      {method === "fixed" && (
        <label className="text-sm">
          <span className="block mb-1 text-black/60">السعر الثابت (دج)</span>
          <input
            type="number"
            min={0}
            step="0.01"
            value={fixedAmount}
            onChange={(e) => setFixedAmount(e.target.value)}
            className="w-full rounded-lg border border-border px-3 py-2 outline-none focus:border-primary"
          />
        </label>
      )}

      {method === "distance" && (
        <div className="grid gap-2 sm:grid-cols-2">
          <label className="text-sm">
            <span className="block mb-1 text-black/60">سعر أساسي (دج)</span>
            <input
              type="number"
              min={0}
              step="0.01"
              value={baseAmount}
              onChange={(e) => setBaseAmount(e.target.value)}
              className="w-full rounded-lg border border-border px-3 py-2 outline-none focus:border-primary"
            />
          </label>
          <label className="text-sm">
            <span className="block mb-1 text-black/60">سعر الكيلومتر (دج)</span>
            <input
              type="number"
              min={0}
              step="0.01"
              value={perKmAmount}
              onChange={(e) => setPerKmAmount(e.target.value)}
              className="w-full rounded-lg border border-border px-3 py-2 outline-none focus:border-primary"
            />
          </label>
        </div>
      )}

      {method === "zone" && (
        <p className="text-xs text-black/50">
          حدّد سعر كل بلدية من الجدول أسفل هذه البطاقة.
        </p>
      )}

      <div className="grid gap-2 sm:grid-cols-2 pt-2 border-t border-border">
        <label className="text-sm">
          <span className="block mb-1 text-black/60">حصة الموصّل</span>
          <select
            value={shareType}
            onChange={(e) => setShareType(e.target.value as DeliveryShareType)}
            className="w-full rounded-lg border border-border px-3 py-2 outline-none focus:border-primary"
          >
            <option value="percentage">نسبة % من رسم التوصيل</option>
            <option value="fixed">مبلغ ثابت (دج)</option>
          </select>
        </label>
        <label className="text-sm">
          <span className="block mb-1 text-black/60">
            {shareType === "percentage" ? "النسبة (%)" : "المبلغ (دج)"}
          </span>
          <input
            type="number"
            min={0}
            max={shareType === "percentage" ? 100 : undefined}
            step="0.01"
            value={shareValue}
            onChange={(e) => setShareValue(e.target.value)}
            className="w-full rounded-lg border border-border px-3 py-2 outline-none focus:border-primary"
          />
        </label>
      </div>

      <div className="flex items-center gap-3">
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-primary text-white font-semibold px-5 py-2 text-sm disabled:opacity-60"
        >
          حفظ
        </button>
        {error && <p className="text-error text-xs">{error}</p>}
        {saved && !error && <p className="text-primary text-xs">تم الحفظ</p>}
      </div>
    </form>
  );
}
