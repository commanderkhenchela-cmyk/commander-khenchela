"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { createClient } from "@/lib/supabase/client";
import type { Category, Product } from "@/lib/types";

interface ProductFormProps {
  merchantId: string;
  categories: Category[];
  /** عند التعديل: المنتج الحالي وصورته الحالية (إن وُجدت). */
  initialProduct?: Product;
  initialImageUrl?: string;
}

const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 ميغابايت

export default function ProductForm({
  merchantId,
  categories,
  initialProduct,
  initialImageUrl,
}: ProductFormProps) {
  const router = useRouter();
  const isEdit = !!initialProduct;

  const [name, setName] = useState(initialProduct?.name ?? "");
  const [categoryId, setCategoryId] = useState(
    initialProduct?.category_id ?? categories[0]?.id ?? "",
  );
  const [price, setPrice] = useState(
    initialProduct ? String(initialProduct.price) : "",
  );
  const [description, setDescription] = useState(
    initialProduct?.description ?? "",
  );
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(
    initialImageUrl ?? null,
  );
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  function handleImageChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > MAX_IMAGE_BYTES) {
      setError("حجم الصورة كبير جدًا (الحد الأقصى 5 ميغابايت).");
      return;
    }

    setError(null);
    setImageFile(file);
    setPreviewUrl(URL.createObjectURL(file));
  }

  /** ترفع الصورة داخل مجلد باسم المحل، مطابقةً لشرط RLS على bucket الصور. */
  async function uploadImage(
    supabase: ReturnType<typeof createClient>,
    productId: string,
  ): Promise<string | null> {
    if (!imageFile) return null;

    const ext = imageFile.name.split(".").pop() ?? "jpg";
    const path = `${merchantId}/${productId}-${Date.now()}.${ext}`;

    const { error: uploadError } = await supabase.storage
      .from("product-images")
      .upload(path, imageFile, { upsert: true });

    if (uploadError) {
      throw new Error("تعذّر رفع الصورة");
    }

    const {
      data: { publicUrl },
    } = supabase.storage.from("product-images").getPublicUrl(path);

    return publicUrl;
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const priceValue = Number(price);

    if (isNaN(priceValue) || priceValue < 0) {
      setError("السعر غير صالح.");
      setLoading(false);
      return;
    }

    if (!categoryId) {
      setError("لا يوجد أي تصنيف متاح حاليًا. تواصل مع الإدارة لإضافة تصنيفات.");
      setLoading(false);
      return;
    }

    let productId = initialProduct?.id;

    if (isEdit) {
      const { error: updateError } = await supabase
        .from("products")
        .update({
          name,
          category_id: categoryId,
          price: priceValue,
          description: description || null,
        })
        .eq("id", productId);

      if (updateError) {
        setError("تعذّر حفظ التعديلات.");
        setLoading(false);
        return;
      }
    } else {
      const { data, error: insertError } = await supabase
        .from("products")
        .insert({
          merchant_id: merchantId,
          category_id: categoryId,
          name,
          price: priceValue,
          description: description || null,
        })
        .select("id")
        .single();

      if (insertError || !data) {
        setError("تعذّر إضافة المنتج.");
        setLoading(false);
        return;
      }
      productId = data.id;
    }

    // صورة جديدة فقط إذا اختار التاجر ملفًا — عند التعديل بدون اختيار ملف
    // جديد، تبقى الصورة الحالية كما هي بدون أي تغيير.
    if (imageFile && productId) {
      try {
        const publicUrl = await uploadImage(supabase, productId);
        if (publicUrl) {
          if (isEdit) {
            await supabase
              .from("product_images")
              .delete()
              .eq("product_id", productId);
          }
          await supabase.from("product_images").insert({
            product_id: productId,
            image_url: publicUrl,
            sort_order: 0,
          });
        }
      } catch {
        setError("تم حفظ المنتج، لكن تعذّر رفع الصورة. عدّل المنتج لإعادة المحاولة.");
        setLoading(false);
        return;
      }
    }

    router.replace("/dashboard/products");
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4 max-w-lg">
      <div>
        <label className="block text-sm font-medium mb-1">اسم المنتج</label>
        <input
          type="text"
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">التصنيف</label>
        {categories.length === 0 ? (
          <p className="text-sm text-warning">
            لا توجد تصنيفات متاحة بعد — تواصل مع الإدارة.
          </p>
        ) : (
          <select
            required
            value={categoryId}
            onChange={(e) => setCategoryId(e.target.value)}
            className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary bg-white"
          >
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        )}
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">السعر (دج)</label>
        <input
          type="number"
          required
          min={0}
          step="0.01"
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          الوصف (اختياري)
        </label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={3}
          className="w-full rounded-lg border border-border px-3 py-2.5 outline-none focus:border-primary"
        />
      </div>

      <div>
        <label className="block text-sm font-medium mb-1">
          صورة المنتج (اختياري)
        </label>
        {previewUrl && (
          <div className="mb-2 relative w-24 h-24 rounded-lg overflow-hidden border border-border">
            <Image
              src={previewUrl}
              alt="معاينة الصورة"
              fill
              unoptimized
              className="object-cover"
            />
          </div>
        )}
        <input
          type="file"
          accept="image/*"
          onChange={handleImageChange}
          className="w-full text-sm"
        />
        <p className="text-xs text-black/50 mt-1">JPG أو PNG، حتى 5 ميغابايت</p>
      </div>

      {error && <p className="text-error text-sm">{error}</p>}

      <button
        type="submit"
        disabled={loading}
        className="w-full rounded-lg bg-primary text-white font-semibold py-3 mt-2 disabled:opacity-60"
      >
        {loading ? "جارٍ الحفظ..." : isEdit ? "حفظ التعديلات" : "إضافة المنتج"}
      </button>
    </form>
  );
}
