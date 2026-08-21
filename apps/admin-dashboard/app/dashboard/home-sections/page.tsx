import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import { HOME_SECTION_KEY_LABELS, type HomeSection } from "@/lib/types";
import HomeSectionActions from "./home-section-actions";

export default async function HomeSectionsPage() {
  const context = await getAdminContext();
  if (!context?.canManageStores) redirect("/dashboard");

  const supabase = await createClient();
  const { data: sections } = await supabase
    .from("home_sections")
    .select("id, section_key, title, sort_order, is_active, created_at")
    .order("sort_order");

  const items = (sections ?? []) as HomeSection[];

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-1">أقسام الصفحة الرئيسية</h1>
      <p className="text-black/60 mb-6 text-sm">
        تتحكّم هنا بأي الأقسام تظهر للعميل في الصفحة الرئيسية، بأي ترتيب،
        وبأي عنوان. القسم يختفي تلقائيًا من التطبيق أيضًا إن لم توجد له
        بيانات كافية (مثلًا لا يوجد بعد متجر مميّز)، حتى لو كان مفعَّلًا هنا.
      </p>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد أقسام — تحقّق من قاعدة البيانات.</p>
      ) : (
        <div className="grid gap-2">
          {items.map((section, index) => (
            <div
              key={section.id}
              className="rounded-xl border border-border bg-card p-4"
            >
              <div className="flex items-center justify-between gap-3 mb-1">
                <span className="text-xs text-black/40">
                  {HOME_SECTION_KEY_LABELS[section.section_key]}
                </span>
                <HomeSectionActions
                  sectionId={section.id}
                  title={section.title}
                  isActive={section.is_active}
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
                  currentSortOrder={section.sort_order}
                />
              </div>
              <p
                className={`font-semibold ${
                  section.is_active ? "" : "text-black/40 line-through"
                }`}
              >
                {section.title}
              </p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
