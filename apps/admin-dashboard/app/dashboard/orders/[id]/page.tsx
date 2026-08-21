import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import { ORDER_STATUS_LABELS, type AdminOrder } from "@/lib/types";
import OrderActions from "./order-actions";
import DeliveryFeeForm from "./delivery-fee-form";

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
      `id, status, subtotal, delivery_fee, total_amount, merchant_amount, platform_commission_amount, created_at,
       merchants(store_name, phone),
       addresses(address_text, phone, communes(name)),
       order_items(id, product_id, quantity, unit_price, subtotal, products(name))`,
    )
    .eq("id", id)
    .maybeSingle();

  if (!order) notFound();

  const o = order as unknown as AdminOrder;

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
        <p className="font-semibold mb-1">المحل</p>
        <p className="text-black/70">
          {o.merchants?.store_name} — {o.merchants?.phone}
        </p>
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

      <div className="rounded-xl border border-border bg-card p-5">
        <p className="font-semibold mb-3">الإجراء</p>
        <OrderActions orderId={o.id} status={o.status} />
      </div>
    </div>
  );
}
