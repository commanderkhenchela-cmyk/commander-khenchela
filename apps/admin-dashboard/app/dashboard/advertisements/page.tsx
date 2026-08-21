import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import type { Advertisement } from "@/lib/types";
import AdActions from "./ad-actions";

export default async function AdvertisementsPage() {
  const supabase = await createClient();
  const { data: ads } = await supabase
    .from("advertisements")
    .select(
      "id, title, advertiser_name, thumbnail_url, is_active, start_date, end_date, sort_order, views_count, clicks_count",
    )
    .order("sort_order");

  const items = (ads ?? []) as Pick<
    Advertisement,
    | "id"
    | "title"
    | "advertiser_name"
    | "thumbnail_url"
    | "is_active"
    | "start_date"
    | "end_date"
    | "sort_order"
    | "views_count"
    | "clicks_count"
  >[];

  return (
    <div className="max-w-2xl">
      <div className="flex items-center justify-between mb-1">
        <h1 className="text-2xl font-bold">لوحة إعلانات الفيديو</h1>
        <Link
          href="/dashboard/advertisements/new"
          className="rounded-lg bg-primary text-white font-semibold px-4 py-2.5 text-sm"
        >
          + إعلان جديد
        </Link>
      </div>
      <p className="text-black/60 mb-6 text-sm">
        تظهر الإعلانات النشطة كشريط فيديو أعلى الصفحة الرئيسية لتطبيق
        العميل، مرتَّبة حسب الأولوية أدناه.
      </p>

      {items.length === 0 ? (
        <p className="text-black/60">لا توجد إعلانات بعد.</p>
      ) : (
        <div className="grid gap-3">
          {items.map((ad) => {
            const ctr =
              ad.views_count > 0
                ? ((ad.clicks_count / ad.views_count) * 100).toFixed(1)
                : "—";

            return (
              <div
                key={ad.id}
                className="rounded-xl border border-border bg-card p-4 flex items-center gap-4"
              >
                <div className="w-16 h-16 rounded-lg overflow-hidden bg-background shrink-0 flex items-center justify-center">
                  {ad.thumbnail_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={ad.thumbnail_url}
                      alt={ad.title}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <span className="text-2xl">🎬</span>
                  )}
                </div>

                <div className="flex-1 min-w-0">
                  <Link
                    href={`/dashboard/advertisements/${ad.id}`}
                    className="font-semibold hover:text-primary block truncate"
                  >
                    {ad.title}
                  </Link>
                  <p className="text-sm text-black/60 truncate">
                    {ad.advertiser_name}
                  </p>
                  <p className="text-xs text-black/40 mt-1">
                    {ad.views_count} مشاهدة · {ad.clicks_count} نقرة · CTR{" "}
                    {ctr}
                    {ctr !== "—" && "%"}
                  </p>
                </div>

                <AdActions
                  adId={ad.id}
                  isActive={ad.is_active}
                  title={ad.title}
                />
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
