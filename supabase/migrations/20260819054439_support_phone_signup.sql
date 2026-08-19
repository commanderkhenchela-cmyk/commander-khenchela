-- ============================================================
-- Migration: دعم التسجيل برقم الهاتف (Phone + Twilio Verify)
-- ============================================================
-- عند التسجيل برقم الهاتف، يخزّن Supabase الرقم في عمود auth.users.phone
-- مباشرة (وليس بالضرورة داخل raw_user_meta_data). نحدّث الدالة لتفضيل
-- هذا العمود، مع الإبقاء على raw_user_meta_data كخيار احتياطي.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, role, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'role', 'customer'),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.phone, new.raw_user_meta_data ->> 'phone')
  );
  return new;
end;
$$;

comment on function public.handle_new_user is 'ينشئ تلقائيًا ملفًا شخصيًا عند تسجيل حساب جديد، سواء بالبريد أو بالهاتف';
