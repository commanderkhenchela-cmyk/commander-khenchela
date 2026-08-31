import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";
import type { Product } from "@/lib/types";
import ProductActions from "./product-actions";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { PackageIcon, PlusIcon } from "@/components/ui/icons";

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
        <Button href="/dashboard/products/new" size="sm">
          <PlusIcon className="h-4 w-4" />
          إضافة منتج
        </Button>
      </div>

      {items.length === 0 ? (
        <EmptyState
          icon={<PackageIcon className="h-8 w-8" />}
          title="لا توجد منتجات بعد"
          description="أضف منتجك الأول ليظهر للعملاء."
        />
      ) : (
        <div className="grid gap-3">
          {items.map((product) => (
            <Card key={product.id} padding="p-4" className="flex items-center justify-between gap-4">
              <div className="min-w-0">
                <p className="font-semibold truncate">{product.name}</p>
                <p className="text-sm text-black/60 flex items-center gap-2">
                  {product.price.toFixed(0)} دج
                  {!product.is_active && <Badge tone="warning">غير نشط</Badge>}
                </p>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                <Link
                  href={`/dashboard/products/${product.id}/edit`}
                  className="text-sm font-medium text-primary px-3 py-1.5"
                >
                  تعديل
                </Link>
                <ProductActions productId={product.id} isActive={product.is_active} />
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
