import type { Metadata } from "next";
import { Cairo } from "next/font/google";
import "./globals.css";

const cairo = Cairo({
  variable: "--font-cairo",
  subsets: ["arabic", "latin"],
});

export const metadata: Metadata = {
  title: "لوحة تحكم التاجر — Commander Khenchela",
  description: "لوحة تحكم التاجر لإدارة المنتجات والطلبات",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "تاجر Khenchela",
  },
  icons: {
    apple: "/icons/icon-192.png",
  },
};

export const viewport = {
  themeColor: "#1B7A3D",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ar" dir="rtl" className={`${cairo.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col bg-background text-foreground">
        {children}
      </body>
    </html>
  );
}
