import type { ReactNode, SVGProps } from "react";

/**
 * أيقونات SVG مرسومة يدويًا — بديل موحّد للـ emoji المتفرّقة (💰 🔔 ⏳ ✕ +)
 * التي كانت تُستخدم كأيقونات في هذا التطبيق. لا تبعية npm جديدة (لا
 * lucide-react ولا أي مكتبة أيقونات) — كل أيقونة svg إنلاين بسيطة،
 * قابلة للتلوين عبر currentColor، وaria-hidden لأنها زخرفية دائمًا
 * (النص المجاور لها هو من يحمل المعنى لقارئ الشاشة).
 */
type IconProps = SVGProps<SVGSVGElement>;

function Icon({ children, ...props }: IconProps & { children: ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      {...props}
    >
      {children}
    </svg>
  );
}

export function HomeIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M4 11.5 12 4l8 7.5" />
      <path d="M6 10v9a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-9" />
      <path d="M10 20v-5h4v5" />
    </Icon>
  );
}

export function ClipboardListIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <rect x="6" y="4" width="12" height="17" rx="2" />
      <path d="M9 4V3a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1" />
      <path d="M9 10h6M9 13.5h6M9 17h4" />
    </Icon>
  );
}

export function PackageIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M12 3 4 7.5v9L12 21l8-4.5v-9L12 3Z" />
      <path d="M4 7.5 12 12l8-4.5M12 12v9" />
    </Icon>
  );
}

export function ClockIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 7.5V12l3 2" />
    </Icon>
  );
}

export function WalletIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M4 7.5A2.5 2.5 0 0 1 6.5 5h11A2.5 2.5 0 0 1 20 7.5V9h-4a2 2 0 0 0 0 4h4v3.5A2.5 2.5 0 0 1 17.5 19h-11A2.5 2.5 0 0 1 4 16.5v-9Z" />
      <circle cx="16.2" cy="11" r="0.9" fill="currentColor" stroke="none" />
    </Icon>
  );
}

export function BellIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M6 9a6 6 0 0 1 12 0c0 4 1.5 5.5 2 6H4c.5-.5 2-2 2-6Z" />
      <path d="M10 19a2 2 0 0 0 4 0" />
    </Icon>
  );
}

export function SettingsIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M4 6h9M17 6h3M4 12h3M9 12h11M4 18h13M20 18h0" />
      <circle cx="15" cy="6" r="2" />
      <circle cx="7" cy="12" r="2" />
      <circle cx="17" cy="18" r="2" />
    </Icon>
  );
}

export function LogOutIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M9 5H6.5A2.5 2.5 0 0 0 4 7.5v9A2.5 2.5 0 0 0 6.5 19H9" />
      <path d="M15 8l4 4-4 4" />
      <path d="M19 12H9" />
    </Icon>
  );
}

export function PictureIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <rect x="3.5" y="4.5" width="17" height="15" rx="2" />
      <circle cx="9" cy="10" r="1.6" />
      <path d="M4 17.5 9 12.5l3 3 4-4.5 4 4.5" />
    </Icon>
  );
}

export function AlertTriangleIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M12 3.5 21.5 20H2.5L12 3.5Z" />
      <path d="M12 9.5v4.5" />
      <circle cx="12" cy="17" r="1" fill="currentColor" stroke="none" />
    </Icon>
  );
}

export function CheckIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M5 12.5 10 17.5 19 7" />
    </Icon>
  );
}

export function XCircleIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M9 9l6 6M15 9l-6 6" />
    </Icon>
  );
}

export function PlusIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M12 5v14M5 12h14" />
    </Icon>
  );
}

export function HourglassIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M6 4h12M6 20h12" />
      <path d="M7 4c0 4 3 5 5 6-2 1-5 2-5 6M17 4c0 4-3 5-5 6 2 1 5 2 5 6" />
    </Icon>
  );
}
