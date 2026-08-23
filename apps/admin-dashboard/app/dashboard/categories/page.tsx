import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import type { Category } from "@/lib/types";
import CategoryForm from "./category-form";
import CategoryActions from "./category-actions";

export default async function CategoriesPage() {
  const context = await getAdminContext();
  if (!context?.canManageStores) redirect("/dashboard");

  const supabase = await createClient();
  const { data: categories } = await supabase
    .from("categories")
    .select("id, name, is_active, created_at")
    .order("name");

  const items = (categories ?? []) as Category[];

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-6">التصنيفات</h1>

      <div className="rounded-xl border border-border bg-card p-5 mb-6">
        <p className="font-semibold mb-3">إضافة تصنيف جديد</p>
        <CategoryForm />
      </div>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد تصنيفات بعد.</p>
      ) : (
        <div className="grid gap-2">
          {items.map((c) => (
            <div
              key={c.id}
              className="rounded-xl border border-border bg-card p-4 flex items-center justify-between"
            >
              <span className={c.is_active ? "" : "text-black/40 line-through"}>
                {c.name}
              </span>
              <CategoryActions categoryId={c.id} isActive={c.is_active} />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
