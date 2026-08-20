// ============================================================
// Edge Function: send-order-notification (PHASE 11)
//
// لماذا Edge Function وليس Postgres function عادية؟ لأنها الوحيدة
// هنا التي تحتاج فعليًا نداء خدمة خارجية (Firebase Cloud Messaging عبر
// HTTPS) — بالضبط القرار المعماري الموثَّق في create_order (Phase 6):
// عمل DB بحت → دالة Postgres، عمل يحتاج خدمة خارجية → Edge Function.
//
// كيف تُستدعى: عبر "Database Webhook" في Supabase Dashboard
// (Database → Webhooks)، مضبوطة على جدول orders، أحداث INSERT وUPDATE.
// Supabase يرسل تلقائيًا payload بالشكل:
//   { type: "INSERT" | "UPDATE", table, schema, record, old_record }
// وهذا يوفّر بديلًا أبسط بكثير من كتابة pg_net + Vault يدويًا — كل
// الإعداد يتم بنقرات في الواجهة، بدون SQL إضافي.
//
// الأسرار المطلوبة (تُضبط في Supabase Dashboard → Edge Functions →
// Secrets، ليست في الكود ولا في GitHub إطلاقًا):
//   FCM_PROJECT_ID     — معرّف مشروع Firebase
//   FCM_CLIENT_EMAIL   — بريد Service Account من Firebase
//   FCM_PRIVATE_KEY    — المفتاح الخاص من نفس ملف Service Account JSON
// (SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY متوفرة تلقائيًا لكل Edge
// Function في مشروع Supabase، لا حاجة لضبطهما يدويًا)
// ============================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const ORDER_STATUS_LABELS: Record<string, string> = {
  confirmed: "تم تأكيد طلبك من طرف التاجر",
  preparing: "طلبك الآن قيد التجهيز",
  ready_for_pickup: "طلبك جاهز، بانتظار المندوب",
  picked_up: "استلم المندوب طلبك",
  out_for_delivery: "طلبك في الطريق إليك",
  delivered: "تم تسليم طلبك، بالهناء والشفاء",
  cancelled: "تم إلغاء طلبك",
  rejected: "لم يوافق التاجر على طلبك",
};

interface OrderRow {
  id: string;
  customer_id: string;
  merchant_id: string;
  status: string;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: OrderRow;
  old_record: OrderRow | null;
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    if (payload.table !== "orders") {
      return new Response("ignored: not orders table", { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let targetUserId: string | null = null;
    let title = "";
    let body = "";
    let notifType = "";

    if (payload.type === "INSERT") {
      // طلب جديد — نُخبر التاجر (وليس العميل، هو من أرسله)
      const { data: merchant } = await supabase
        .from("merchants")
        .select("owner_user_id")
        .eq("id", payload.record.merchant_id)
        .maybeSingle();

      if (merchant) {
        targetUserId = merchant.owner_user_id;
        title = "طلب جديد 🛍️";
        body = "وصلك طلب جديد بانتظار موافقتك";
        notifType = "new_order";
      }
    } else if (payload.type === "UPDATE") {
      const oldStatus = payload.old_record?.status;
      const newStatus = payload.record.status;

      if (oldStatus && oldStatus !== newStatus && ORDER_STATUS_LABELS[newStatus]) {
        targetUserId = payload.record.customer_id;
        title = "تحديث طلبك";
        body = ORDER_STATUS_LABELS[newStatus];
        notifType = `order_${newStatus}`;
      }
    }

    if (!targetUserId) {
      return new Response("ignored: no notification needed", { status: 200 });
    }

    // نسجّل الإشعار دائمًا في الجدول (يظهر داخل التطبيق حتى لو فشل الـ
    // push الخارجي أو لم يكن للمستخدم جهاز مسجَّل بعد)
    await supabase.from("notifications").insert({
      user_id: targetUserId,
      title,
      body,
      type: notifType,
    });

    const { data: user } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", targetUserId)
      .maybeSingle();

    if (!user?.fcm_token) {
      return new Response("saved in-app only: no fcm_token", { status: 200 });
    }

    await sendPush(user.fcm_token, title, body);

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("send-order-notification error:", err);
    // نرجع 200 دائمًا: هذا webhook من Supabase، إرجاع خطأ يجعله يعيد
    // المحاولة بلا داعٍ لخطأ منطقي في المحتوى (مثل توكن منتهي الصلاحية)
    return new Response("error logged", { status: 200 });
  }
});

async function sendPush(fcmToken: string, title: string, body: string) {
  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL")!;
  const privateKey = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");

  const auth = new GoogleAuth({
    credentials: { client_email: clientEmail, private_key: privateKey },
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const accessToken = await auth.getAccessToken();

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
        },
      }),
    },
  );

  if (!response.ok) {
    console.error("FCM send failed:", response.status, await response.text());
  }
}
