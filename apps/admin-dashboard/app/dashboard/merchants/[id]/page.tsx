import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { Merchant, MerchantCategory } from "@/lib/types";
import MerchantActions from "./merchant-actions";
import MerchantCategorySelect from "./merchant-category-select";
import MerchantFeaturedToggle from "./merchant-featured-toggle";
import EntityActivityLog from "@/components/entity-activity-log";

export default async function MerchantDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.canManageStores) redirect("/dashboard");

  const { id } = await params;
  const supabase = await createClient();

  const { data: merchant } = await supabase
    .from("merchants")
    .select(
      "id, owner_user_id, store_name, wilaya_id, commune_id, address_text, phone, status, category_id, is_featured, orders_count, created_at, communes(name), merchant_categories(name, icon)",
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

  const { data: allCategories } = await supabase
    .from("merchant_categories")
    .select("id, name, icon, sort_order, is_active, parent_id, created_at")
    .order("sort_order");

  const m = merchant as unknown as Merchant;
  const categories = (allCategories ?? []) as MerchantCategory[];

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
        <InfoRow label="عدد الطلبات (كل الأوقات)" value={String(m.orders_count)} />
        <InfoRow
          label="تصنيف المحل"
          value={
            m.merchant_categories
              ? `${m.merchant_categories.icon} ${m.merchant_categories.name}`
              : "بدون تصنيف"
          }
        />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">صاحب المحل</p>
        <InfoRow label="الاسم" value={owner?.full_name ?? "—"} />
        <InfoRow label="الهاتف" value={owner?.phone ?? "—"} />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">تصنيف المحل</p>
        <MerchantCategorySelect
          merchantId={m.id}
          categoryId={m.category_id}
          categories={categories}
        />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <MerchantFeaturedToggle merchantId={m.id} isFeatured={m.is_featured} />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">الإجراء</p>
        <MerchantActions merchantId={m.id} status={m.status} />
      </div>

      <EntityActivityLog tableName="merchants" recordId={m.id} />
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
