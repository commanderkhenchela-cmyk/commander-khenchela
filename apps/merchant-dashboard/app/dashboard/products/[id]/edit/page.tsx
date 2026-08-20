import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";
import type { Category, Product } from "@/lib/types";
import ProductForm from "../../product-form";

export default async function EditProductPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  const supabase = await createClient();

  const [{ data: product }, { data: categories }, { data: images }] =
    await Promise.all([
      supabase
        .from("products")
        .select(
          "id, merchant_id, category_id, name, description, price, is_active, created_at",
        )
        .eq("id", id)
        .eq("merchant_id", merchant.id)
        .maybeSingle(),
      supabase
        .from("categories")
        .select("id, name, is_active")
        .eq("is_active", true)
        .order("name"),
      supabase
        .from("product_images")
        .select("image_url")
        .eq("product_id", id)
        .order("sort_order")
        .limit(1),
    ]);

  if (!product) notFound();

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">تعديل المنتج</h1>
      <ProductForm
        merchantId={merchant.id}
        categories={(categories ?? []) as Category[]}
        initialProduct={product as Product}
        initialImageUrl={images?.[0]?.image_url}
      />
    </div>
  );
}
