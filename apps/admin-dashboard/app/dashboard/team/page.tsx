import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAdminContext } from "@/lib/admin-context";
import { ADMIN_PANEL_ROLES, type TeamMember } from "@/lib/types";
import RoleSelect from "./role-select";
import UserSearch from "./user-search";

export default async function TeamPage() {
  const context = await getAdminContext();
  if (!context?.isSuperAdmin) redirect("/dashboard");

  const supabase = await createClient();
  const { data: members } = await supabase
    .from("users")
    .select("id, full_name, phone, role, created_at")
    .in("role", ADMIN_PANEL_ROLES)
    .order("role");

  const items = (members ?? []) as TeamMember[];

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-bold mb-1">فريق الإدارة</h1>
      <p className="text-black/60 mb-6 text-sm">
        Super Admin وحده يرى هذه الصفحة، ويملك صلاحية تغيير أدوار الفريق —
        عبر دالة قاعدة بيانات محكومة، وليس تعديلًا مباشرًا على الجدول.
        الحساب الأول (Super Admin) يُنشأ يدويًا عبر Supabase Dashboard؛ من
        هنا يُدار كل ما بعده.
      </p>

      <div className="rounded-xl border border-border bg-card p-5 mb-6">
        <p className="font-semibold mb-3">إضافة عضو للفريق</p>
        <p className="text-sm text-black/60 mb-3">
          ابحث باسم مستخدم مسجَّل فعلًا في التطبيق (عميل أو تاجر) وامنحه
          دورًا إداريًا.
        </p>
        <UserSearch />
      </div>

      {items.length === 0 ? (
        <p className="text-black/60">لا يوجد أعضاء في الفريق حتى الآن.</p>
      ) : (
        <div className="grid gap-2">
          {items.map((member) => (
            <div
              key={member.id}
              className="rounded-xl border border-border bg-card p-4 flex items-center justify-between gap-4"
            >
              <div className="min-w-0">
                <p className="font-medium truncate">
                  {member.full_name || "بدون اسم"}
                </p>
                {member.phone && (
                  <p className="text-sm text-black/50">{member.phone}</p>
                )}
              </div>
              <RoleSelect
                userId={member.id}
                currentRole={member.role}
                disableSelfDemotion={member.id === context.userId}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
