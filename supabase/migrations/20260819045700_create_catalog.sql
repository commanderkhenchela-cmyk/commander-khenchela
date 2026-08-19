-- ============================================================
-- Migration: كتالوج المنتجات — categories, products, product_images
-- ============================================================

-- ---------- categories ----------
create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table categories is 'تصنيفات المنتجات (مُدارة من طرف Admin)';

alter table categories enable row level security;

-- Policy: الكل يقرأ التصنيفات (بيانات عامة، لا تحتاج تسجيل دخول)
create policy "categories_public_read"
  on categories for select
  using (true);

-- ملاحظة: لا Policy لإضافة/تعديل/حذف التصنيفات — فقط Admin عبر Service Role.

-- ---------- products ----------
create table products (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references merchants (id),
  category_id uuid not null references categories (id),
  name text not null,
  description text,
  price numeric(10, 2) not null check (price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table products is 'المنتجات. كل منتج مرتبط بتاجر واحد وتصنيف واحد';

create index products_merchant_id_idx on products (merchant_id);
create index products_category_id_idx on products (category_id);

alter table products enable row level security;

-- Policy: أي شخص يقرأ منتجًا فقط إذا كان نشطًا (is_active)
-- والمحل الذي يملكه مُوافَق عليه من Admin (approved)
create policy "products_public_read"
  on products for select
  using (
    is_active = true
    and exists (
      select 1 from merchants m
      where m.id = products.merchant_id and m.status = 'approved'
    )
  );

-- Policy: التاجر يرى كل منتجاته الخاصة (حتى غير النشطة)
create policy "products_select_own_merchant"
  on products for select
  using (
    exists (
      select 1 from merchants m
      where m.id = products.merchant_id and m.owner_user_id = auth.uid()
    )
  );

-- Policy: التاجر يضيف منتجًا فقط لمحله الخاص، وفقط إذا كان محله موافَقًا عليه
create policy "products_insert_own_merchant"
  on products for insert
  with check (
    exists (
      select 1 from merchants m
      where m.id = products.merchant_id
        and m.owner_user_id = auth.uid()
        and m.status = 'approved'
    )
  );

-- Policy: التاجر يعدّل فقط منتجاته الخاصة
create policy "products_update_own_merchant"
  on products for update
  using (
    exists (
      select 1 from merchants m
      where m.id = products.merchant_id and m.owner_user_id = auth.uid()
    )
  );

-- Policy: التاجر يحذف فقط منتجاته الخاصة
create policy "products_delete_own_merchant"
  on products for delete
  using (
    exists (
      select 1 from merchants m
      where m.id = products.merchant_id and m.owner_user_id = auth.uid()
    )
  );

-- ---------- product_images ----------
create table product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products (id) on delete cascade,
  image_url text not null,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now()
);

comment on table product_images is 'صور المنتجات، عدة صور لكل منتج، مرتبة بـ sort_order';

create index product_images_product_id_idx on product_images (product_id);

alter table product_images enable row level security;

-- Policy: نفس شرط قراءة المنتج نفسه (نشط + محل موافَق عليه)
create policy "product_images_public_read"
  on product_images for select
  using (
    exists (
      select 1 from products p
      join merchants m on m.id = p.merchant_id
      where p.id = product_images.product_id
        and p.is_active = true
        and m.status = 'approved'
    )
  );

-- Policy: التاجر يدير (قراءة/إضافة/تعديل/حذف) صور منتجاته الخاصة فقط
create policy "product_images_owner_all"
  on product_images for all
  using (
    exists (
      select 1 from products p
      join merchants m on m.id = p.merchant_id
      where p.id = product_images.product_id and m.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from products p
      join merchants m on m.id = p.merchant_id
      where p.id = product_images.product_id and m.owner_user_id = auth.uid()
    )
  );
