import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Merchant } from "@/lib/types";
import MerchantActions from "./merchant-actions";

export default async function MerchantDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: merchant } = await supabase
    .from("merchants")
    .select(
      "id, owner_user_id, store_name, wilaya_id, commune_id, address_text, phone, status, created_at, communes(name)",
    )
    .eq("id", id)
    .maybeSingle();

  if (!merchant) notFound();

  const { data: owner } = await supabase
    .from("users")
    .select("full_name, phone, created_at")
    .eq("id", merchant.owner_user_id)
    .maybeSingle();

  const { count: productsCount } = await supabase
    .from("products")
    .select("id", { count: "exact", head: true })
    .eq("merchant_id", id);

  const m = merchant as unknown as Merchant;

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">{m.store_name}</h1>
      <p className="text-black/60 mb-6">
        تاريخ التسجيل: {new Date(m.created_at).toLocaleDateString("ar-DZ")}
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">بيانات المحل</p>
        <InfoRow label="البلدية" value={m.communes?.name ?? "—"} />
        <InfoRow label="العنوان" value={m.address_text ?? "—"} />
        <InfoRow label="هاتف المحل" value={m.phone ?? "—"} />
        <InfoRow label="عدد المنتجات" value={String(productsCount ?? 0)} />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">صاحب المحل</p>
        <InfoRow label="الاسم" value={owner?.full_name ?? "—"} />
        <InfoRow label="الهاتف" value={owner?.phone ?? "—"} />
      </div>

      <div className="rounded-xl border border-border bg-card p-5">
        <p className="font-semibold mb-3">الإجراء</p>
        <MerchantActions merchantId={m.id} status={m.status} />
      </div>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between text-sm py-1.5 border-b border-border last:border-b-0">
      <span className="text-black/60">{label}</span>
      <span className="font-medium">{value}</span>
    </div>
  );
}
