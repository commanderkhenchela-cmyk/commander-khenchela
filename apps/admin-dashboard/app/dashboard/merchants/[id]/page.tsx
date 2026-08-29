import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { Merchant, MerchantCategory, WalletTransaction } from "@/lib/types";
import { WALLET_TRANSACTION_LABELS } from "@/lib/types";
import MerchantActions from "./merchant-actions";
import MerchantCategorySelect from "./merchant-category-select";
import MerchantFeaturedToggle from "./merchant-featured-toggle";
import WalletTopupForm from "./wallet-topup-form";
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
        <div className="rounded-xl border border-border bg-card p-5 mb-4">
          <div className="flex items-center justify-between mb-3">
            <p className="font-semibold">محفظة التاجر</p>
            <span
              className={`text-lg font-bold ${
                walletBalance < 0 ? "text-error" : "text-primary"
              }`}
            >
              {walletBalance.toFixed(2)} دج
            </span>
          </div>
          <p className="text-xs text-black/50 mb-3">
            لا يوجد بوابة دفع إلكترونية — الدفع يتم في المكتب. الرصيد =
            مجموع كل الحركات أدناه (إيداعات + عمولات الطلبات المُسلَّمة
            تلقائيًا − أي خصم يدوي).
          </p>

          {canManageWallet && (
            <div className="grid gap-2 mb-4 sm:grid-cols-2">
              <WalletTopupForm merchantId={m.id} kind="topup" />
              <WalletTopupForm merchantId={m.id} kind="deduction" />
            </div>
          )}

          {walletTransactions.length === 0 ? (
            <p className="text-sm text-black/50">لا توجد حركات مسجَّلة بعد.</p>
          ) : (
            <div className="grid gap-2">
              {walletTransactions.map((t) => (
                <div
                  key={t.id}
                  className="flex items-center justify-between gap-3 text-sm border-b border-border last:border-b-0 pb-2 last:pb-0"
                >
                  <div className="min-w-0">
                    <p className="font-medium">
                      {WALLET_TRANSACTION_LABELS[t.type]}
                    </p>
                    {t.note && (
                      <p className="text-xs text-black/50 truncate">{t.note}</p>
                    )}
                    <p className="text-xs text-black/40">
                      {new Date(t.created_at).toLocaleString("ar-DZ")}
                    </p>
                  </div>
                  <span
                    className={`shrink-0 font-semibold ${
                      t.amount >= 0 ? "text-primary" : "text-error"
                    }`}
                  >
                    {t.amount >= 0 ? "+" : ""}
                    {t.amount.toFixed(2)} دج
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
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
