-- ============================================================
-- Migration: تتبّع عمليات البحث الشائعة (Popular Searches) — نفس نمط
-- increment_merchant_view بالضبط (migration 20260821100000): عدّاد لا
-- يُعدَّل أبدًا بـ insert/update مباشر من العميل، فقط عبر دالة RPC
-- محكومة (record_search_query) — يمنع بنيويًا أي تلاعب بالأرقام من
-- طرف العميل (تضخيم/تلفيق شعبية بحث معيّن).
--
-- لا بيانات حسّاسة: فقط نص البحث المُطبَّع (حروف صغيرة، بلا مسافات
-- زائدة) وعدد مرات تكراره — بلا ربط بأي مستخدم (user_id) عمدًا، حتى
-- لعميل مسجَّل دخوله، لأن "الشائع" مفهوم عام عبر كل المستخدمين وليس له
-- علاقة بهوية الباحث.
-- ============================================================

create table search_queries (
  id uuid primary key default gen_random_uuid(),
  query text not null unique,
  search_count integer not null default 1,
  last_searched_at timestamptz not null default now()
);

comment on table search_queries is 'عدّاد تكرار كل نص بحث (مُطبَّع: حروف صغيرة + trim)، لبناء "عمليات بحث شائعة" حقيقية. يُحدَّث فقط عبر record_search_query() — راجع تعليق أعلى الملف.';

create index search_queries_count_idx on search_queries (search_count desc);

alter table search_queries enable row level security;

-- القراءة عامة بالكامل: لا شيء حسّاس هنا، والغرض أصلًا عرضها لكل عميل.
create policy "search_queries_select_public"
  on search_queries for select
  using (true);

-- لا سياسة insert/update للعميل مباشرة — الكتابة الوحيدة عبر الدالة
-- أدناه (security definer، تتجاوز RLS لصفّها الخاص فقط).
create function public.record_search_query(p_query text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_normalized text := trim(lower(p_query));
begin
  -- تجاهل بحث قصير جدًا (حرف واحد مثلًا) — ضجيج بلا فائدة لقائمة الشائع.
  if length(v_normalized) < 2 then
    return;
  end if;

  insert into search_queries (query, search_count, last_searched_at)
  values (v_normalized, 1, now())
  on conflict (query) do update
  set search_count = search_queries.search_count + 1,
      last_searched_at = now();
end;
$$;
