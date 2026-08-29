import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import {
  ORDER_STATUS_LABELS,
  WALLET_TRANSACTION_LABELS,
  type AdminOrder,
  type AppNotification,
  type WalletTransaction,
} from "@/lib/types";
import OrderActions from "./order-actions";
import DeliveryFeeForm from "./delivery-fee-form";
import EntityActivityLog from "@/components/entity-activity-log";

export default async function OrderDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const context = await getAdminContext();
  if (!context?.isSuperAdmin) redirect("/dashboard");

  const { id } = await params;
  const supabase = await createClient();

  const { data: order } = await supabase
    .from("orders")
    .select(
      `id, customer_id, status, subtotal, delivery_fee, total_amount, merchant_amount, platform_commission_amount, created_at,
       merchants(store_name, phone, latitude, longitude),
       addresses(address_text, phone, communes(name)),
       order_items(id, product_id, quantity, unit_price, subtotal, products(name)),
       drivers(full_name, phone, is_online, current_lat, current_lng)`,
    )
    .eq("id", id)
    .maybeSingle();

  if (!order) notFound();

  const o = order as unknown as AdminOrder;

  // ============================================================
  // التتبّع الشامل (PRD قسم 24): بيانات موجودة أصلًا فـ جداول منفصلة
  // (users، wallet_transactions، notifications، fraud_cases) — تُجمَع
  // هنا فقط للعرض، بلا أي تعديل على أي منها. كل استعلام مستقل ويتحمّل
  // نتيجة فارغة بأمان (Empty State حقيقي، لا بيانات وهمية).
  // ============================================================
  const [
    { data: customer },
    { data: walletEntry },
    { data: orderNotifications },
    { data: fraudRows },
  ] = await Promise.all([
    supabase
      .from("users")
      .select("full_name, phone, is_suspended")
      .eq("id", o.customer_id)
      .maybeSingle(),
    supabase
      .from("wallet_transactions")
      .select("id, merchant_id, type, amount, note, order_id, created_at")
      .eq("order_id", o.id)
      .eq("type", "commission")
      .maybeSingle(),
    supabase
      .from("notifications")
      .select("id, title, body, type, is_read, created_at, entity_type, entity_id")
      .eq("entity_type", "order")
      .eq("entity_id", o.id)
      .order("created_at", { ascending: false }),
    supabase
      .from("fraud_cases")
      .select("violation_count, status")
      .eq("user_id", o.customer_id),
  ]);

  const customerInfo = customer as {
    full_name: string;
    phone: string | null;
    is_suspended: boolean;
  } | null;
  const commissionEntry = walletEntry as WalletTransaction | null;
  const notificationsForOrder = (orderNotifications ?? []) as AppNotification[];
  const customerFraudTotal = (fraudRows ?? []).reduce(
    (sum, r) => sum + Number((r as { violation_count: number }).violation_count),
    0,
  );

  return (
    <div className="max-w-xl">
      <h1 className="text-2xl font-bold mb-1">تفاصيل الطلب</h1>
      <p className="text-black/60 mb-6">
        {new Date(o.created_at).toLocaleString("ar-DZ")}
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-1">الحالة الحالية</p>
        <p className="text-primary font-bold">{ORDER_STATUS_LABELS[o.status]}</p>
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <div className="flex items-center justify-between gap-2">
          <p className="font-semibold mb-1">العميل</p>
          {customerFraudTotal > 0 && (
            <Link
              href="/dashboard/fraud"
              className="text-xs text-error font-semibold shrink-0"
            >
              {customerFraudTotal} مخالفة مسجَّلة
            </Link>
          )}
        </div>
        <p className="text-black/70">
          {customerInfo?.full_name || "—"} — {customerInfo?.phone ?? "—"}
        </p>
        {customerInfo?.is_suspended && (
          <p className="text-error text-sm font-semibold mt-1">حساب موقوف حاليًا</p>
        )}
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-1">المحل</p>
        <p className="text-black/70">
          {o.merchants?.store_name} — {o.merchants?.phone}
        </p>
        {o.merchants?.latitude && o.merchants?.longitude ? (
          <p className="text-xs text-black/40 mt-1">
            الموقع: {o.merchants.latitude.toFixed(5)}, {o.merchants.longitude.toFixed(5)}
          </p>
        ) : (
          <p className="text-xs text-black/40 mt-1">لم يحدَّد موقع المحل بعد</p>
        )}
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-1">الموصّل</p>
        <p className="text-black/70">
          {o.drivers
            ? `${o.drivers.full_name} — ${o.drivers.phone}`
            : "لم يُعيَّن موصّل بعد"}
        </p>
        {o.drivers && (
          <p className="text-xs text-black/40 mt-1">
            {o.drivers.is_online ? "متصل الآن" : "غير متصل"}
            {o.drivers.current_lat && o.drivers.current_lng
              ? ` — آخر موقع: ${o.drivers.current_lat.toFixed(5)}, ${o.drivers.current_lng.toFixed(5)}`
              : " — لا يوجد موقع مسجَّل بعد"}
          </p>
        )}
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-1">عنوان التوصيل</p>
        <p className="text-black/70">
          {o.addresses?.communes?.name} — {o.addresses?.address_text}
        </p>
        <p className="text-black/70 mt-1">هاتف العميل: {o.addresses?.phone ?? "—"}</p>
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">المنتجات</p>
        <div className="flex flex-col gap-2">
          {o.order_items?.map((item) => (
            <div key={item.id} className="flex justify-between text-sm">
              <span>
                {item.products?.name ?? "منتج"} × {item.quantity}
              </span>
              <span>{item.subtotal.toFixed(0)} دج</span>
            </div>
          ))}
        </div>
        <div className="border-t border-border mt-3 pt-3 flex justify-between font-semibold">
          <span>المجموع الفرعي</span>
          <span>{o.subtotal.toFixed(0)} دج</span>
        </div>
        <div className="flex justify-between text-sm text-black/60 mt-1">
          <span>رسوم التوصيل</span>
          <span>{o.delivery_fee.toFixed(0)} دج</span>
        </div>
        <div className="flex justify-between font-bold mt-1">
          <span>الإجمالي (يدفعه العميل)</span>
          <span>{o.total_amount.toFixed(0)} دج</span>
        </div>
        <div className="flex justify-between text-sm text-black/60 mt-2 pt-2 border-t border-border">
          <span>عمولة المنصة</span>
          <span>{o.platform_commission_amount.toFixed(0)} دج</span>
        </div>
        <div className="flex justify-between text-sm text-black/60">
          <span>مستحقات التاجر</span>
          <span>{o.merchant_amount.toFixed(0)} دج</span>
        </div>
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">رسوم التوصيل</p>
        <DeliveryFeeForm orderId={o.id} currentFee={o.delivery_fee} />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">الإجراء</p>
        <OrderActions orderId={o.id} status={o.status} />
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">أثر الطلب على المحفظة</p>
        {commissionEntry ? (
          <div className="flex items-center justify-between text-sm">
            <span>{WALLET_TRANSACTION_LABELS[commissionEntry.type]}</span>
            <span className="font-semibold text-error">
              {commissionEntry.amount.toFixed(2)} دج
            </span>
          </div>
        ) : (
          <p className="text-sm text-black/50">
            لا توجد حركة عمولة بعد — تُسجَّل تلقائيًا فقط عند وصول الطلب
            لحالة &quot;تم التسليم&quot;.
          </p>
        )}
      </div>

      <div className="rounded-xl border border-border bg-card p-5 mb-4">
        <p className="font-semibold mb-3">الإشعارات المرتبطة بهذا الطلب</p>
        {notificationsForOrder.length === 0 ? (
          <p className="text-sm text-black/50">لا توجد إشعارات مرتبطة بعد.</p>
        ) : (
          <div className="grid gap-2">
            {notificationsForOrder.map((n) => (
              <div key={n.id} className="text-sm border-b border-border last:border-b-0 pb-2 last:pb-0">
                <p className="font-medium">{n.title}</p>
                <p className="text-black/60">{n.body}</p>
                <p className="text-xs text-black/40 mt-0.5">
                  {new Date(n.created_at).toLocaleString("ar-DZ")}
                  {n.is_read ? " — مقروء" : " — غير مقروء"}
                </p>
              </div>
            ))}
          </div>
        )}
      </div>

      <EntityActivityLog tableName="orders" recordId={o.id} />
    </div>
  );
}
