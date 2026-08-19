-- ============================================================
-- Migration: orders, order_items, order_status_history
-- يطبّق فعليًا دورة حياة الطلب المتفق عليها في PHASE 1:
-- pending -> confirmed/rejected -> preparing -> ready_for_pickup
--          -> picked_up -> out_for_delivery -> delivered
-- + cancelled كحالة نهائية ممكنة من عدة نقاط
-- ============================================================

create table orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references users (id),
  merchant_id uuid not null references merchants (id),
  address_id uuid not null references addresses (id),
  status text not null default 'pending' check (status in (
    'pending', 'confirmed', 'preparing', 'ready_for_pickup',
    'picked_up', 'out_for_delivery', 'delivered', 'cancelled', 'rejected'
  )),
  subtotal numeric(10, 2) not null check (subtotal >= 0),
  commission_rate numeric(5, 2) not null,
  platform_commission_amount numeric(10, 2) not null check (platform_commission_amount >= 0),
  merchant_amount numeric(10, 2) not null check (merchant_amount >= 0),
  delivery_fee numeric(10, 2) not null default 0 check (delivery_fee >= 0),
  total_amount numeric(10, 2) not null check (total_amount >= 0),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'collected')),
  created_at timestamptz not null default now()
);

comment on table orders is 'الطلبية. تتضمن حقول العمولة كـ Snapshot ثابت وقت الإنشاء';

create index orders_customer_id_idx on orders (customer_id);
create index orders_merchant_id_idx on orders (merchant_id);
create index orders_status_idx on orders (status);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
  product_id uuid not null references products (id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(10, 2) not null check (unit_price >= 0),
  subtotal numeric(10, 2) not null check (subtotal >= 0)
);

comment on table order_items is 'تفاصيل كل طلبية: أي منتجات وبأي كمية. غير قابلة للتعديل بعد الإنشاء';

create index order_items_order_id_idx on order_items (order_id);

create table order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders (id) on delete cascade,
  from_status text,
  to_status text not null,
  changed_by uuid references users (id),
  changed_at timestamptz not null default now()
);

comment on table order_status_history is 'سجل كل تغيير في حالة الطلب - يُكتب تلقائيًا فقط، غير قابل للتعديل';

create index order_status_history_order_id_idx on order_status_history (order_id);

-- ============================================================
-- المحرّك: التحقق من صحة كل انتقال حالة، حسب دور صاحب الطلب
-- ============================================================
create function public.validate_order_status_transition()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  actor_role text;
  is_merchant_owner boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  -- Edge Functions الموثوقة (Service Role) تتجاوز هذا الفحص
  if auth.role() = 'service_role' then
    return new;
  end if;

  select role into actor_role from users where id = auth.uid();

  is_merchant_owner := exists (
    select 1 from merchants m
    where m.id = new.merchant_id and m.owner_user_id = auth.uid()
  );

  if old.status in ('delivered', 'cancelled', 'rejected') then
    raise exception 'لا يمكن تغيير حالة طلب في حالة نهائية (%)', old.status;
  end if;

  if old.status = 'pending' and new.status = 'confirmed' and is_merchant_owner then
    return new;
  elsif old.status = 'pending' and new.status = 'rejected' and is_merchant_owner then
    return new;
  elsif old.status = 'pending' and new.status = 'cancelled'
        and (new.customer_id = auth.uid() or actor_role = 'admin') then
    return new;
  elsif old.status = 'confirmed' and new.status = 'preparing' and is_merchant_owner then
    return new;
  elsif old.status = 'confirmed' and new.status = 'cancelled' and actor_role = 'admin' then
    return new;
  elsif old.status = 'preparing' and new.status = 'ready_for_pickup' and is_merchant_owner then
    return new;
  elsif old.status = 'preparing' and new.status = 'cancelled' and actor_role = 'admin' then
    return new;
  elsif old.status = 'ready_for_pickup' and new.status = 'picked_up' and actor_role = 'admin' then
    return new;
  elsif old.status = 'picked_up' and new.status = 'out_for_delivery' and actor_role = 'admin' then
    return new;
  elsif old.status = 'out_for_delivery' and new.status = 'delivered' and actor_role = 'admin' then
    return new;
  else
    raise exception 'انتقال حالة غير مسموح: من % إلى %', old.status, new.status;
  end if;
end;
$$;

create trigger orders_validate_status_transition
  before update on orders
  for each row execute function public.validate_order_status_transition();

-- ============================================================
-- التسجيل التلقائي: كل تغيير ناجح يُكتب في order_status_history
-- ============================================================
create function public.log_order_creation()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into order_status_history (order_id, from_status, to_status, changed_by)
  values (new.id, null, new.status, auth.uid());
  return new;
end;
$$;

create trigger orders_log_creation
  after insert on orders
  for each row execute function public.log_order_creation();

create function public.log_order_status_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    insert into order_status_history (order_id, from_status, to_status, changed_by)
    values (new.id, old.status, new.status, auth.uid());
  end if;
  return new;
end;
$$;

create trigger orders_log_status_change
  after update on orders
  for each row execute function public.log_order_status_change();

-- ============================================================
-- الأمان (RLS)
-- ============================================================
alter table orders enable row level security;
alter table order_items enable row level security;
alter table order_status_history enable row level security;

-- orders: القراءة
create policy "orders_select_own_customer"
  on orders for select
  using (customer_id = auth.uid());

create policy "orders_select_own_merchant"
  on orders for select
  using (
    exists (select 1 from merchants m where m.id = orders.merchant_id and m.owner_user_id = auth.uid())
  );

-- orders: الإنشاء (العميل فقط، وبحالة pending إجباريًا)
create policy "orders_insert_own_customer"
  on orders for insert
  with check (customer_id = auth.uid() and status = 'pending');

-- orders: التعديل — RLS تسمح باللمس، والـ Trigger أعلاه يقرر إن كان الانتقال مسموحًا
create policy "orders_update_customer"
  on orders for update
  using (customer_id = auth.uid());

create policy "orders_update_merchant"
  on orders for update
  using (
    exists (select 1 from merchants m where m.id = orders.merchant_id and m.owner_user_id = auth.uid())
  );

-- order_items: القراءة
create policy "order_items_select_customer"
  on order_items for select
  using (exists (select 1 from orders o where o.id = order_items.order_id and o.customer_id = auth.uid()));

create policy "order_items_select_merchant"
  on order_items for select
  using (
    exists (
      select 1 from orders o
      join merchants m on m.id = o.merchant_id
      where o.id = order_items.order_id and m.owner_user_id = auth.uid()
    )
  );

-- order_items: الإنشاء (فقط ضمن طلب pending خاص بنفس العميل)
create policy "order_items_insert_customer"
  on order_items for insert
  with check (
    exists (
      select 1 from orders o
      where o.id = order_items.order_id and o.customer_id = auth.uid() and o.status = 'pending'
    )
  );
-- ملاحظة: لا Policy لتعديل/حذف order_items — غير قابلة للتغيير بعد الإنشاء (سجل ثابت)

-- order_status_history: القراءة فقط (الكتابة تتم تلقائيًا عبر الـ Triggers أعلاه فقط)
create policy "order_status_history_select_customer"
  on order_status_history for select
  using (exists (select 1 from orders o where o.id = order_status_history.order_id and o.customer_id = auth.uid()));

create policy "order_status_history_select_merchant"
  on order_status_history for select
  using (
    exists (
      select 1 from orders o
      join merchants m on m.id = o.merchant_id
      where o.id = order_status_history.order_id and m.owner_user_id = auth.uid()
    )
  );
