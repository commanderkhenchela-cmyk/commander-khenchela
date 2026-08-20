import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";
import type { Product } from "@/lib/types";
import ProductActions from "./product-actions";

export default async function ProductsPage() {
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  const supabase = await createClient();
  const { data: products } = await supabase
    .from("products")
    .select("id, merchant_id, category_id, name, description, price, is_active, created_at")
    .eq("merchant_id", merchant.id)
    .order("created_at", { ascending: false });

  const items = (products ?? []) as Product[];

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">المنتجات</h1>
        <Link
          href="/dashboard/products/new"
          className="rounded-lg bg-primary text-white font-semibold px-4 py-2.5 text-sm"
        >
          + إضافة منتج
        </Link>
      </div>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد منتجات بعد. أضف منتجك الأول.</p>
      ) : (
        <div className="grid gap-3">
          {items.map((product) => (
            <div
              key={product.id}
              className="rounded-xl border border-border bg-card p-4 flex items-center justify-between gap-4"
            >
              <div className="min-w-0">
                <p className="font-semibold truncate">{product.name}</p>
                <p className="text-sm text-black/60">
                  {product.price.toFixed(0)} دج
                  {!product.is_active && (
                    <span className="text-warning font-medium"> · غير نشط</span>
                  )}
                </p>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                <Link
                  href={`/dashboard/products/${product.id}/edit`}
                  className="text-sm font-medium text-primary px-3 py-1.5"
                >
                  تعديل
                </Link>
                <ProductActions
                  productId={product.id}
                  isActive={product.is_active}
                />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
