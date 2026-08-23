import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { MerchantCategory } from "@/lib/types";
import MerchantCategoryForm from "./merchant-category-form";
import MerchantCategoryActions from "./merchant-category-actions";

// تصنيفات المحلات (مطاعم، بقالة، صيدليات...) — تختلف عن صفحة "التصنيفات"
// الأخرى في القائمة الجانبية، والتي تصنّف المنتجات *داخل* محل واحد فقط.
// هذه الصفحة تتحكّم بالتصنيف الذي يظهر للعميل كشبكة أيقونات في أول
// شاشة يفتحها بعد تأكيد الولاية، قبل أي قائمة محلات.
export default async function MerchantCategoriesPage() {
  const context = await getAdminContext();
  if (!context?.canManageStores) redirect("/dashboard");

  const supabase = await createClient();
  const { data: categories } = await supabase
    .from("merchant_categories")
    .select("id, name, icon, sort_order, is_active, parent_id, created_at")
    .order("sort_order");

  const items = (categories ?? []) as MerchantCategory[];

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">تصنيفات المحلات</h1>
      <p className="text-black/60 mb-6 text-sm">
        هذه هي التصنيفات التي يراها العميل كشبكة أيقونات (مطاعم، بقالة،
        صيدليات...) قبل أي قائمة محلات. رتّبها بالأسهم، وأخفِ ما لا تريد
        عرضه الآن دون حذفه نهائيًا.
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-6">
        <p className="font-semibold mb-3">إضافة تصنيف جديد</p>
        <MerchantCategoryForm nextSortOrder={items.length + 1} />
      </div>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد تصنيفات بعد.</p>
      ) : (
        <div className="grid gap-2">
          {items.map((c, index) => (
            <div
              key={c.id}
              className="rounded-xl border border-border bg-card p-4 flex items-center gap-3"
            >
              <span className="text-2xl leading-none">{c.icon}</span>
              <span
                className={`flex-1 font-medium ${
                  c.is_active ? "" : "text-black/40 line-through"
                }`}
              >
                {c.name}
              </span>
              <MerchantCategoryActions
                categoryId={c.id}
                icon={c.icon}
                name={c.name}
                isActive={c.is_active}
                isFirst={index === 0}
                isLast={index === items.length - 1}
                prevId={index > 0 ? items[index - 1].id : null}
                prevSortOrder={index > 0 ? items[index - 1].sort_order : null}
                nextId={
                  index < items.length - 1 ? items[index + 1].id : null
                }
                nextSortOrder={
                  index < items.length - 1
                    ? items[index + 1].sort_order
                    : null
                }
                currentSortOrder={c.sort_order}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
