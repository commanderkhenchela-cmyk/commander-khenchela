import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { Driver, DriverWalletTransaction } from "@/lib/types";
import {
  DRIVER_VEHICLE_TYPE_ICONS,
  DRIVER_VEHICLE_TYPE_LABELS,
  DRIVER_WALLET_TRANSACTION_LABELS,
} from "@/lib/types";
import EntityStatusActions from "@/components/entity-status-actions";
import WalletSection from "@/components/wallet-section";
import EntityActivityLog from "@/components/entity-activity-log";

export default async function DriverDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.canManageStores) redirect("/dashboard");

  const { id } = await params;
  const supabase = await createClient();

  const { data: driver } = await supabase
    .from("drivers")
    .select(
      "id, user_id, full_name, phone, vehicle_type, plate_number, status, is_online, id_card_path, created_at, rating_avg, rating_count",
    )
    .eq("id", id)
    .maybeSingle();

  if (!driver) notFound();

  // رابط مؤقّت (Signed URL) لبطاقة التعريف — bucket خاص (driver-documents)،
  // لا رابط عام إطلاقًا. صالح ساعة واحدة، يُولَّد من جديد فـ كل تحميل
  // للصفحة (لا حاجة لتخزينه).
  let idCardSignedUrl: string | null = null;
  if (driver.id_card_path) {
    const { data: signed } = await supabase.storage
      .from("driver-documents")
      .createSignedUrl(driver.id_card_path, 3600);
    idCardSignedUrl = signed?.signedUrl ?? null;
  }

  const { data: account } = await supabase
    .from("users")
    .select("created_at")
    .eq("id", driver.user_id)
    .maybeSingle();

  const { count: activeJobsCount } = await supabase
    .from("orders")
    .select("id", { count: "exact", head: true })
    .eq("driver_id", id)
    .not("status", "in", "(delivered,cancelled,rejected)");

  const d = driver as Driver;

  const canViewWallet = context.hasCapability("wallet.view");
  const canManageWallet = context.hasCapability("wallet.manage");

  let walletTransactions: DriverWalletTransaction[] = [];
  let walletBalance = 0;
  if (canViewWallet) {
    // نفس نمط صفحة تفاصيل التاجر بالحرف: نجلب كل السجل لحساب رصيد دقيق،
    // ونعرض أحدث 30 حركة فقط.
    const { data: transactions } = await supabase
      .from("driver_wallet_transactions")
      .select(
        "id, driver_id, type, amount, note, order_id, ride_request_id, delivery_request_id, created_at",
      )
      .eq("driver_id", id)
      .order("created_at", { ascending: false });
    const all = (transactions ?? []) as DriverWalletTransaction[];
    walletTransactions = all.slice(0, 30);
    walletBalance = all.reduce((sum, row) => sum + Number(row.amount), 0);
  }

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">{d.full_name}</h1>
      <p className="text-black/60 mb-6">
        تاريخ التسجيل: {new Date(d.created_at).toLocaleDateString("ar-DZ")}
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">بيانات الموصّل</p>
        <InfoRow label="الهاتف" value={d.phone} />
        <InfoRow
          label="نوع المركبة"
          value={`${DRIVER_VEHICLE_TYPE_ICONS[d.vehicle_type]} ${DRIVER_VEHICLE_TYPE_LABELS[d.vehicle_type]}`}
        />
        <InfoRow label="رقم اللوحة" value={d.plate_number ?? "—"} />
        <InfoRow
          label="التقييم"
          value={
            d.rating_count > 0
              ? `⭐ ${d.rating_avg.toFixed(1)} (${d.rating_count} تقييم)`
              : "لا تقييمات بعد"
          }
        />
        <InfoRow label="متصل الآن" value={d.is_online ? "نعم" : "لا"} />
        <InfoRow
          label="طلبات قيد التنفيذ حاليًا"
          value={String(activeJobsCount ?? 0)}
        />
        <InfoRow
          label="تاريخ إنشاء الحساب"
          value={
            account?.created_at
              ? new Date(account.created_at).toLocaleDateString("ar-DZ")
              : "—"
          }
        />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">بطاقة التعريف</p>
        {idCardSignedUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={idCardSignedUrl}
            alt="بطاقة تعريف الموصّل"
            className="w-full max-w-xs rounded-lg border border-border object-cover"
          />
        ) : (
          <p className="text-sm text-black/50">
            لم يرفع الموصّل صورة بطاقة تعريفه — لا تتم الموافقة على أي
            موصّل بلا وثيقة هوية.
          </p>
        )}
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">الإجراء</p>
        <EntityStatusActions
          tableName="drivers"
          entityId={d.id}
          status={d.status}
          entityLabel="الموصّل"
        />
      </div>

      {canViewWallet && (
        <WalletSection
          title="محفظة الموصّل"
          description={
            'لا يوجد بوابة دفع إلكترونية — الدفع يتم في المكتب. الرصيد = مجموع كل الحركات أدناه (إيداعات + عمولات المهام المُنجَزة تلقائيًا − أي خصم يدوي). العمولة تُخصَم من أي مهمة (طلبية، رحلة Taxi، أو طلب "اطلب أي شيء") عند اكتمالها فعليًا.'
          }
          entityIdParamName="p_driver_id"
          entityId={d.id}
          topupRpc="admin_driver_wallet_topup"
          deductRpc="admin_driver_wallet_deduct"
          canManageWallet={canManageWallet}
          transactions={walletTransactions}
          balance={walletBalance}
          labels={DRIVER_WALLET_TRANSACTION_LABELS}
        />
      )}

      <EntityActivityLog tableName="drivers" recordId={d.id} />
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
