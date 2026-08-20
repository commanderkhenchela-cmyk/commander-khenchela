import { redirect } from "next/navigation";
import { getMerchantContext } from "@/lib/merchant-context";

/**
 * الصفحة الجذر: توجّه التاجر تلقائيًا للمكان الصحيح حسب حالته —
 * غير مسجَّل → تسجيل الدخول
 * لا يملك محلًا بعد → إنشاء المحل
 * محله قيد المراجعة → صفحة الانتظار
 * محله مرفوض → صفحة الرفض
 * محله موافَق عليه → لوحة التحكم
 */
export default async function RootPage() {
  const context = await getMerchantContext();

  if (!context) redirect("/login");

  if (!context.merchant) redirect("/onboarding");

  switch (context.merchant.status) {
    case "approved":
      redirect("/dashboard");
    case "pending":
      redirect("/pending");
    case "rejected":
      redirect("/rejected");
    default:
      redirect("/login");
  }
}
