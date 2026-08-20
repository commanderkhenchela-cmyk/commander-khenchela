import { redirect } from "next/navigation";
import { getAdminContext } from "@/lib/admin-context";
import LogoutButton from "@/components/logout-button";

export default async function RootPage() {
  const context = await getAdminContext();

  if (!context) redirect("/login");

  if (!context.isAdmin) {
    return (
      <main className="flex flex-1 items-center justify-center p-6">
        <div className="w-full max-w-sm rounded-2xl bg-card border border-border p-8 shadow-sm text-center">
          <div className="text-5xl mb-4">🚫</div>
          <h1 className="text-xl font-bold mb-2">هذا الحساب ليس حساب إدارة</h1>
          <p className="text-black/70">
            هذه اللوحة مخصَّصة لفريق الإدارة فقط. إذا كنت تاجرًا، استخدم لوحة
            تحكم التاجر بدلًا من هذه.
          </p>
          <div className="mt-4 rounded-lg bg-black/5 p-3 text-left text-xs text-black/60 break-all">
            <p>userId: {context.userId}</p>
            <p>email: {context.email}</p>
            <p>profile: {JSON.stringify(context.debugProfile)}</p>
            <p>error: {context.debugError ?? "none"}</p>
          </div>
          <LogoutButton className="inline-block mt-6 text-primary font-semibold" />
        </div>
      </main>
    );
  }

  redirect("/dashboard");
}
