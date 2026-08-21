import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Advertisement } from "@/lib/types";
import AdForm from "../ad-form";

export default async function EditAdvertisementPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: ad } = await supabase
    .from("advertisements")
    .select(
      "id, title, description, advertiser_name, video_url, thumbnail_url, link_url, start_date, end_date, sort_order, is_active, views_count, video_starts_count, video_completions_count, clicks_count, created_at",
    )
    .eq("id", id)
    .maybeSingle();

  if (!ad) notFound();

  const a = ad as Advertisement;
  const ctr =
    a.views_count > 0 ? ((a.clicks_count / a.views_count) * 100).toFixed(1) : "—";
  const completionRate =
    a.video_starts_count > 0
      ? ((a.video_completions_count / a.video_starts_count) * 100).toFixed(1)
      : "—";

  return (
    <div className="max-w-lg">
      <h1 className="text-2xl font-bold mb-6">تعديل الإعلان</h1>

      <div className="rounded-xl border border-border bg-card p-5 mb-6">
        <p className="font-semibold mb-3">الإحصائيات</p>
        <div className="grid grid-cols-2 gap-3 text-sm">
          <Stat label="مشاهدات" value={a.views_count} />
          <Stat label="بدء تشغيل الفيديو" value={a.video_starts_count} />
          <Stat label="اكتمال المشاهدة" value={a.video_completions_count} />
          <Stat label="نقرات" value={a.clicks_count} />
          <Stat label="نسبة النقر (CTR)" value={ctr === "—" ? "—" : `${ctr}%`} />
          <Stat
            label="نسبة إكمال الفيديو"
            value={completionRate === "—" ? "—" : `${completionRate}%`}
          />
        </div>
      </div>

      <AdForm ad={a} />
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg bg-background p-3">
      <p className="text-xl font-bold">{value}</p>
      <p className="text-black/50 text-xs mt-0.5">{label}</p>
    </div>
  );
}
