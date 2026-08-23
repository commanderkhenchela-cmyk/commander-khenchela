-- إضافة orders لنشر Realtime — بدونها، اشتراكات postgres_changes الجديدة
-- في تطبيق الزبون (my_orders_screen.dart، order_detail_screen.dart،
-- commit c258063) لا تستقبل أي حدث إطلاقًا رغم عدم وجود أي خطأ ظاهر
-- (الاشتراك ينجح، لكن Postgres لا ينشر تغييرات هذا الجدول أصلًا لتيار
-- الـ Realtime). محمي بنفس سياسات RLS الحالية على orders (Realtime
-- Authorization يحترم RLS تلقائيًا لكل عميل مسجَّل دخوله).
alter publication supabase_realtime add table orders;
