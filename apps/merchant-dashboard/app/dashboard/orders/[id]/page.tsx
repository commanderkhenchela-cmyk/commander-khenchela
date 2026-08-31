import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";
import { ORDER_STATUS_LABELS, type MerchantOrder } from "@/lib/types";
import { ORDER_STATUS_TONE } from "@/lib/order-status";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import OrderActions from "./order-actions";

export default async function OrderDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  const supabase = await createClient();
  const { data: order } = await supabase
    .from("orders")
    .select(
      `id, status, subtotal, delivery_fee, total_amount, merchant_amount, created_at,
       addresses(address_text, communes(name)),
       order_items(id, product_id, quantity, unit_price, subtotal, products(name))`,
    )
    .eq("id", id)
    .eq("merchant_id", merchant.id)
    .maybeSingle();

  if (!order) notFound();

  const o = order as unknown as MerchantOrder;

  return (
    <div className="max-w-xl">
      <h1 className="text-2xl font-bold mb-1">تفاصيل الطلب</h1>
      <p className="text-black/60 mb-6">
        {new Date(o.created_at).toLocaleString("ar-DZ")}
      </p>

      <Card className="mb-4">
        <p className="font-semibold mb-2">الحالة الحالية</p>
        <Badge tone={ORDER_STATUS_TONE[o.status]}>{ORDER_STATUS_LABELS[o.status]}</Badge>
      </Card>

      <Card className="mb-4">
        <p className="font-semibold mb-1">عنوان التوصيل</p>
        <p className="text-black/70">
          {o.addresses?.communes?.name} — {o.addresses?.address_text}
        </p>
      </Card>

      <Card className="mb-4">
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
          <span>رسوم التوصيل (تُحصَّل من الإدارة)</span>
          <span>{o.delivery_fee.toFixed(0)} دج</span>
        </div>
        <div className="flex justify-between text-sm text-primary font-semibold mt-2">
          <span>مستحقّاتك من هذا الطلب</span>
          <span>{o.merchant_amount.toFixed(0)} دج</span>
        </div>
      </Card>

      <Card>
        <p className="font-semibold mb-3">الإجراء</p>
        <OrderActions orderId={o.id} status={o.status} />
      </Card>
    </div>
  );
}
