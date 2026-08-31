import Link from "next/link";
import type { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from "react";

export type ButtonVariant = "primary" | "outline" | "danger" | "ghost";
export type ButtonSize = "md" | "sm";

const VARIANT_CLASSES: Record<ButtonVariant, string> = {
  primary: "bg-primary text-white hover:bg-primary-dark",
  outline: "border border-primary text-primary hover:bg-primary/5",
  danger: "border border-error text-error hover:bg-error/5",
  ghost: "text-black/70 hover:bg-black/5",
};

const SIZE_CLASSES: Record<ButtonSize, string> = {
  md: "px-5 py-3 text-sm",
  sm: "px-4 py-2.5 text-sm",
};

/** نفس صيغة الأصناف التي كانت متكرَّرة يدويًا في 6+ ملفات — الآن دالة
 * واحدة، تُستخدَم من Button نفسه وكذلك من أي مكان آخر يحتاج مظهر زر
 * بلا عنصر <button> فعلي (مثل ConfirmDialog). */
export function buttonClasses(variant: ButtonVariant = "primary", size: ButtonSize = "md") {
  return `inline-flex items-center justify-center gap-2 rounded-lg font-semibold transition-colors disabled:opacity-60 disabled:pointer-events-none outline-none focus-visible:ring-2 focus-visible:ring-primary/40 focus-visible:ring-offset-2 ${VARIANT_CLASSES[variant]} ${SIZE_CLASSES[size]}`;
}

interface CommonProps {
  variant?: ButtonVariant;
  size?: ButtonSize;
  className?: string;
  children: ReactNode;
}

type ButtonAsButton = CommonProps &
  Omit<ButtonHTMLAttributes<HTMLButtonElement>, "className"> & { href?: undefined };
type ButtonAsLink = CommonProps &
  Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href" | "className"> & { href: string };

export type ButtonProps = ButtonAsButton | ButtonAsLink;

/** زر واحد يغطي حالتَي "عنصر button فعلي" و"رابط Link بمظهر زر" —
 * الفرق الوحيد بينهما سابقًا في هذا التطبيق كان أي عنصر HTML يُستخدَم،
 * بنفس الأصناف بالضبط منسوخة يدويًا في كل مكان. لا تغيير في أي سلوك
 * نقر/تنقّل — فقط توحيد المظهر. */
export function Button(props: ButtonProps) {
  const { variant = "primary", size = "md", className = "", children, ...rest } = props;
  const classes = `${buttonClasses(variant, size)} ${className}`;

  if ("href" in props && props.href !== undefined) {
    const { href, ...linkRest } = rest as Omit<ButtonAsLink, keyof CommonProps>;
    return (
      <Link href={href} className={classes} {...linkRest}>
        {children}
      </Link>
    );
  }

  return (
    <button className={classes} {...(rest as Omit<ButtonAsButton, keyof CommonProps>)}>
      {children}
    </button>
  );
}
