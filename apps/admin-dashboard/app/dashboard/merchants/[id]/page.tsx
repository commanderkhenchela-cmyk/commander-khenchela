import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { Merchant, MerchantCategory, WalletTransaction } from "@/lib/types";
import { WALLET_TRANSACTION_LABELS } from "@/lib/types";
import MerchantActions from "./merchant-actions";
import MerchantCategorySelect from "./merchant-category-select";
import MerchantFeaturedToggle from "./merchant-featured-toggle";
import WalletSection from "@/components/wallet-section";
import CommissionOverrideForm from "./commission-override-form";
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
      "id, owner_user_id, store_name, wilaya_id, commune_id, address_text, phone, status, category_id, is_featured, orders_count, commission_rate_override, created_at, communes(name), merchant_categories(name, icon)",
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

  const canViewWallet = context.hasCapability("wallet.view");
  const canManageWallet = context.hasCapability("wallet.manage");
  const canManageCommission = context.hasCapability("settings.manage");

  let defaultCommissionRate = "—";
  if (canManageCommission) {
    const { data: settings } = await supabase.rpc("admin_get_settings");
    const rate = (settings ?? []).find(
      (s: { key: string; value: string }) => s.key === "platform_commission_rate",
    );
    defaultCommissionRate = rate?.value ?? "—";
  }

  let walletTransactions: WalletTransaction[] = [];
  let walletBalance = 0;
  if (canViewWallet) {
    // نجلب كل حركات هذا التاجر (بلا حد) — الرصيد يجب أن يكون مجموعًا
    // دقيقًا لكل السجل، لا لصفحة محدودة فقط. عرض الواجهة يعرض أحدث 30
    // منها فقط (slice)، لكن الحساب يستخدم المصفوفة الكاملة.
    const { data: transactions } = await supabase
      .from("wallet_transactions")
      .select("id, merchant_id, type, amount, note, order_id, created_at")
      .eq("merchant_id", id)
      .order("created_at", { ascending: false });
    const all = (transactions ?? []) as WalletTransaction[];
    walletTransactions = all.slice(0, 30);
    walletBalance = all.reduce((sum, row) => sum + Number(row.amount), 0);
  }

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

      {canViewWallet && (
        <WalletSection
          title="محفظة التاجر"
          description="لا يوجد بوابة دفع إلكترونية — الدفع يتم في المكتب. الرصيد = مجموع كل الحركات أدناه (إيداعات + عمولات الطلبات المُسلَّمة تلقائيًا − أي خصم يدوي)."
          entityIdParamName="p_merchant_id"
          entityId={m.id}
          topupRpc="admin_wallet_topup"
          deductRpc="admin_wallet_deduct"
          canManageWallet={canManageWallet}
          transactions={walletTransactions}
          balance={walletBalance}
          labels={WALLET_TRANSACTION_LABELS}
        />
      )}

      {canManageCommission && (
        <div className="rounded-xl border border-border bg-card p-5 mb-4">
          <p className="font-semibold mb-1">عمولة هذا المحل</p>
          <p className="text-xs text-black/50 mb-3">
            {m.commission_rate_override !== null
              ? `يستخدم نسبة خاصة (${m.commission_rate_override}%) بدل النسبة العامة.`
              : `يستخدم النسبة العامة حاليًا (${defaultCommissionRate}%). أدخل نسبة أدناه لاستثنائه.`}
          </p>
          <CommissionOverrideForm
            merchantId={m.id}
            currentOverride={m.commission_rate_override}
            defaultRate={defaultCommissionRate}
          />
        </div>
      )}

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
