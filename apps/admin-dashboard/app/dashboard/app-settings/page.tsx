import { createClient } from "@/lib/supabase/server";
import type { AppContact } from "@/lib/types";
import ContactForm from "./contact-form";

export default async function AppSettingsPage() {
  const supabase = await createClient();
  const { data: contact } = await supabase
    .from("app_contact")
    .select(
      "id, whatsapp_number, display_phone, support_email, facebook_url, instagram_url, updated_at",
    )
    .eq("id", "default")
    .single();

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">بيانات التواصل</h1>
      <p className="text-sm text-black/60 mb-6">
        تظهر هذه البيانات في شاشة &quot;المساعدة&quot; داخل تطبيق الزبون —
        تغييرها هنا يظهر مباشرة عند فتح التطبيق من جديد.
      </p>
      <ContactForm contact={contact as AppContact} />
    </div>
  );
}
