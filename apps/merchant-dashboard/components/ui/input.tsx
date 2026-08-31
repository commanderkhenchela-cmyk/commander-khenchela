import { forwardRef } from "react";
import type {
  InputHTMLAttributes,
  LabelHTMLAttributes,
  ReactNode,
  SelectHTMLAttributes,
  TextareaHTMLAttributes,
} from "react";

/** نفس صيغة حقل الإدخال المتكرّرة يدويًا في 15+ مكانًا — الإضافة الوحيدة
 * الحقيقية هنا هي focus-visible:ring (كان outline-none بلا أي بديل
 * مرئي للتركيز عبر لوحة المفاتيح — ثغرة إتاحة، الإصلاح بصري بحت). */
const fieldClasses =
  "w-full rounded-lg border border-border px-3 py-2.5 outline-none transition-colors focus:border-primary focus-visible:ring-2 focus-visible:ring-primary/30";

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  function Input({ className = "", ...rest }, ref) {
    return <input ref={ref} className={`${fieldClasses} ${className}`} {...rest} />;
  },
);

export const Textarea = forwardRef<
  HTMLTextAreaElement,
  TextareaHTMLAttributes<HTMLTextAreaElement>
>(function Textarea({ className = "", ...rest }, ref) {
  return <textarea ref={ref} className={`${fieldClasses} ${className}`} {...rest} />;
});

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  function Select({ className = "", ...rest }, ref) {
    return <select ref={ref} className={`${fieldClasses} bg-card ${className}`} {...rest} />;
  },
);

export function Label({ className = "", ...rest }: LabelHTMLAttributes<HTMLLabelElement>) {
  return <label className={`block text-sm font-medium mb-1 ${className}`} {...rest} />;
}

/** checkbox + تسمية مرتبطة عبر htmlFor/id فعليًا — hours-form.tsx القديم
 * كان يعتمد على التغليف الضمني فقط (checkbox داخل label، والاسم في
 * span شقيق خارج label)، فلا يعمل النقر على اسم اليوم لتبديل الحالة.
 * id إلزامي هنا عمدًا حتى لا يتكرر نفس الخطأ. */
export function Checkbox({
  id,
  label,
  className = "",
  ...rest
}: InputHTMLAttributes<HTMLInputElement> & { id: string; label: ReactNode }) {
  return (
    <label
      htmlFor={id}
      className={`flex items-center gap-1.5 text-sm text-black/60 cursor-pointer ${className}`}
    >
      <input
        id={id}
        type="checkbox"
        className="h-4 w-4 rounded border-border text-primary focus-visible:ring-2 focus-visible:ring-primary/30"
        {...rest}
      />
      {label}
    </label>
  );
}

export function FieldError({ children }: { children?: ReactNode }) {
  if (!children) return null;
  return <p className="text-error text-sm">{children}</p>;
}

export function FieldSuccess({ children }: { children?: ReactNode }) {
  if (!children) return null;
  return <p className="text-primary text-sm">{children}</p>;
}
