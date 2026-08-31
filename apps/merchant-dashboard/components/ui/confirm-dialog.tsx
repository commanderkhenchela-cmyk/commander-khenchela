"use client";

import { useEffect, useRef } from "react";
import { AlertTriangleIcon } from "./icons";

/**
 * بديل بصري لـ window.confirm() الأصلي (كان يُستخدَم في order-actions.tsx
 * ورفض الطلب، وproduct-actions.tsx وحذف المنتج) — نفس منطق "هل أنت
 * متأكد؟" ونفس استدعاء العملية عند التأكيد بالضبط، فقط حوار مصمَّم بدل
 * نافذة المتصفح الأصلية. مبني على <dialog> الأصلي في المتصفح (showModal/
 * close) — يعطي مجانًا: خلفية معتمة، إغلاق بـ Escape، وتركيز محصور.
 * الجهة المستدعية تتحكم بالفتح/الإغلاق بالكامل عبر `open` (useState محلي
 * في كل ملف يستخدمه)، ولا يُطلق onConfirm إلا عند نقر زر التأكيد فعليًا.
 */
export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = "تأكيد",
  cancelLabel = "إلغاء",
  danger,
  loading,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  loading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) dialog.showModal();
    if (!open && dialog.open) dialog.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      onCancel={onCancel}
      onClose={onCancel}
      className="rounded-2xl border border-border bg-card p-6 max-w-sm w-[90vw] backdrop:bg-black/40"
    >
      <div className="flex items-start gap-3">
        {danger && <AlertTriangleIcon className="h-6 w-6 text-error shrink-0" />}
        <div>
          <p className="font-bold">{title}</p>
          {description && <p className="text-sm text-black/60 mt-1">{description}</p>}
        </div>
      </div>
      <div className="flex gap-3 mt-5">
        <button
          type="button"
          onClick={onConfirm}
          disabled={loading}
          className={`flex-1 rounded-lg font-semibold px-4 py-2.5 text-sm disabled:opacity-60 outline-none focus-visible:ring-2 focus-visible:ring-offset-2 ${
            danger ? "bg-error text-white focus-visible:ring-error/40" : "bg-primary text-white focus-visible:ring-primary/40"
          }`}
        >
          {loading ? "..." : confirmLabel}
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="flex-1 rounded-lg font-semibold px-4 py-2.5 text-sm border border-border text-black/70 hover:bg-black/5 outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
        >
          {cancelLabel}
        </button>
      </div>
    </dialog>
  );
}
