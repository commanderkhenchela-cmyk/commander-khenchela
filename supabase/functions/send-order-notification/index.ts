// ============================================================
// Edge Function: send-order-notification (PHASE 11 + شبكة الإشعارات)
//
// لماذا Edge Function وليس Postgres function عادية؟ لأنها الوحيدة
// هنا التي تحتاج فعليًا نداء خدمة خارجية (Firebase Cloud Messaging عبر
// HTTPS) — بالضبط القرار المعماري الموثَّق في create_order (Phase 6):
// عمل DB بحت → دالة Postgres، عمل يحتاج خدمة خارجية → Edge Function.
//
// كيف تُستدعى: الخيار الأصلي كان "Database Webhook" الجاهز من واجهة
// Supabase (Database → Webhooks) — لكن بعض المشاريع تفتقد جدول/schema
// داخليًا (supabase_functions) يلزم لهذه الميزة تحديدًا (خلل منصّة
// نادر، ظهر فعليًا هنا)، فتفشل إضافة الـ webhook برسالة "schema
// supabase_functions does not exist". البديل المستخدَم هنا بدلًا منها:
// Trigger عادي (نفس الدالة public.notify_order_webhook، عامة وقابلة
// لإعادة الاستخدام على أي جدول) يستدعي هذه الدالة مباشرة عبر
// pg_net.http_post (راجع migration 20260821110000_order_notify_trigger
// و20260822000000_notifications_network) — لا يعتمد على ميزة Webhooks
// الجاهزة إطلاقًا. الشكل النهائي للـ payload مطابق تمامًا لما كانت
// سترجعه ميزة Webhooks أصلًا:
//   { type: "INSERT" | "UPDATE", table, schema, record, old_record }
//
// جداول مُغطّاة حاليًا (كل جدول = فرع مستقل داخل هذه الدالة نفسها،
// حتى لا يتكرّر منطق "اكتب في notifications ثم حاول Push"):
//   - orders    (PHASE 11 الأصلية): تغيّر حالة → الزبون، طلب جديد → التاجر
//   - merchants (شبكة الإشعارات): تسجيل جديد → كل الإدارة، موافقة/رفض → التاجر
//   - drivers   يُضاف لاحقًا مع migration جدول drivers نفسه
//
// حماية بديلة عن التحقق التلقائي من JWT (verify_jwt) — الدالة مَنشورة
// بـ --no-verify-jwt (لأن مفتاح anon الحديث بصيغة sb_publishable_ ليس
// JWT صالحًا لهذا التحقق أصلًا)، والحماية الفعلية هنا: مفتاح سرّي مشترك
// بسيط (WEBHOOK_SECRET) يرسله الـ Trigger في ترويسة x-webhook-secret،
// وتتحقق منه هذه الدالة قبل تنفيذ أي شيء — يمنع أي طرف خارجي (لا يعرف
// السرّ) من انتحال أحداث وهمية.
//
// الأسرار المطلوبة (تُضبط في Supabase Dashboard → Edge Functions →
// Secrets، ليست في الكود ولا في GitHub إطلاقًا):
//   FCM_PROJECT_ID     — معرّف مشروع Firebase
//   FCM_CLIENT_EMAIL   — بريد Service Account من Firebase
//   FCM_PRIVATE_KEY    — المفتاح الخاص من نفس ملف Service Account JSON
//   WEBHOOK_SECRET      — سرّ مشترك عشوائي بين هذه الدالة والـ Trigger
// (SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY متوفرة تلقائيًا لكل Edge
// Function في مشروع Supabase، لا حاجة لضبطهما يدويًا)
// ============================================================

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
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

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Row;
  old_record: Row | null;
}

Deno.serve(async (req) => {
  try {
    const expectedSecret = Deno.env.get("WEBHOOK_SECRET");
    const providedSecret = req.headers.get("x-webhook-secret");
    if (!expectedSecret || providedSecret !== expectedSecret) {
      return new Response("unauthorized", { status: 401 });
    }

    const payload: WebhookPayload = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    if (payload.table === "orders") {
      await handleOrders(supabase, payload);
    } else if (payload.table === "merchants") {
      await handleMerchants(supabase, payload);
    } else {
      return new Response(`ignored: unhandled table ${payload.table}`, { status: 200 });
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("send-order-notification error:", err);
    // نرجع 200 دائمًا: هذا webhook من Supabase، إرجاع خطأ يجعله يعيد
    // المحاولة بلا داعٍ لخطأ منطقي في المحتوى (مثل توكن منتهي الصلاحية)
    return new Response("error logged", { status: 200 });
  }
});

// ---------------------------------------------------------------
// orders: تغيّر حالة → إشعار الزبون، طلب جديد → إشعار صاحب المحل
// ---------------------------------------------------------------
async function handleOrders(supabase: SupabaseClient, payload: WebhookPayload) {
  if (payload.type === "INSERT") {
    const { data: merchant } = await supabase
      .from("merchants")
      .select("owner_user_id")
      .eq("id", payload.record.merchant_id)
      .maybeSingle();

    if (merchant) {
      await notifyUser(supabase, merchant.owner_user_id, "طلب جديد 🛍️", "وصلك طلب جديد بانتظار موافقتك", "new_order");
    }
    return;
  }

  if (payload.type === "UPDATE") {
    const oldStatus = payload.old_record?.status;
    const newStatus = payload.record.status;

    if (oldStatus && oldStatus !== newStatus && ORDER_STATUS_LABELS[newStatus]) {
      await notifyUser(supabase, payload.record.customer_id, "تحديث طلبك", ORDER_STATUS_LABELS[newStatus], `order_${newStatus}`);
    }
  }
}

// ---------------------------------------------------------------
// merchants: تسجيل جديد → كل الإدارة (admin/manager)، موافقة/رفض → التاجر نفسه
// ---------------------------------------------------------------
async function handleMerchants(supabase: SupabaseClient, payload: WebhookPayload) {
  if (payload.type === "INSERT") {
    await notifyAdmins(supabase, "تاجر جديد 🏪", "سجّل تاجر جديد بانتظار الموافقة", "new_merchant");
    return;
  }

  if (payload.type === "UPDATE") {
    const oldStatus = payload.old_record?.status;
    const newStatus = payload.record.status;

    if (oldStatus && oldStatus !== newStatus) {
      if (newStatus === "approved") {
        await notifyUser(supabase, payload.record.owner_user_id, "تمّت الموافقة على محلك 🎉", "يمكنك الآن إضافة منتجاتك واستقبال الطلبات", "merchant_approved");
      } else if (newStatus === "rejected") {
        await notifyUser(supabase, payload.record.owner_user_id, "لم تتم الموافقة على محلك", "راجع بيانات محلك أو تواصل مع الإدارة لمزيد من التفاصيل", "merchant_rejected");
      }
    }
  }
}

// ---------------------------------------------------------------
// أدوات مشتركة: كتابة الإشعار داخل التطبيق دائمًا (لا يعتمد على Push)،
// ثم محاولة Push خارجي إن توفّر fcm_token — يُستخدم من كل الفروع أعلاه
// حتى لا يتكرّر نفس المنطق لكل جدول.
// ---------------------------------------------------------------
async function notifyUser(
  supabase: SupabaseClient,
  userId: string,
  title: string,
  body: string,
  notifType: string,
) {
  await supabase.from("notifications").insert({ user_id: userId, title, body, type: notifType });

  const { data: user } = await supabase
    .from("users")
    .select("fcm_token")
    .eq("id", userId)
    .maybeSingle();

  if (user?.fcm_token) {
    await sendPush(user.fcm_token, title, body);
  }
}

// بثّ لكل الإدارة (admin + manager) — إشعار داخل التطبيق فقط، بدون
// Push (تفاديًا لتعقيد إرسال Push لعدّة أجهزة دفعة واحدة قبل الحاجة
// الفعلية له؛ الإدارة تراقب لوحتها مباشرة).
async function notifyAdmins(
  supabase: SupabaseClient,
  title: string,
  body: string,
  notifType: string,
) {
  const { data: admins } = await supabase
    .from("users")
    .select("id")
    .in("role", ["admin", "manager"]);

  if (!admins || admins.length === 0) return;

  await supabase.from("notifications").insert(
    admins.map((a) => ({ user_id: a.id, title, body, type: notifType })),
  );
}

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
