import { createClient } from "@/lib/supabase/server";
import { getMerchantContext } from "@/lib/merchant-context";
import type { Category } from "@/lib/types";
import ProductForm from "../product-form";

export default async function NewProductPage() {
  const context = await getMerchantContext();
  const merchant = context!.merchant!;

  const supabase = await createClient();
  const { data: categories } = await supabase
    .from("categories")
    .select("id, name, is_active")
    .eq("is_active", true)
    .order("name");

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">إضافة منتج جديد</h1>
      <ProductForm
        merchantId={merchant.id}
        categories={(categories ?? []) as Category[]}
      />
    </div>
  );
}
