"use client";

import { useEffect } from "react";
import { getToken, onMessage, type Messaging } from "firebase/messaging";
import { cleanEnvValue, getMessagingInstance } from "@/lib/firebase";
import { createClient } from "@/lib/supabase/client";

/**
 * يطلب إذن الإشعارات (مرة واحدة) ويحفظ توكن الويب في users.fcm_token —
 * نفس العمود المستخدَم في تطبيقي الزبون والموصّل (Android)، لأن
 * send-order-notification تُرسل لأي توكن صالح بنفس الطريقة بغض النظر
 * عن المنصة (FCM HTTP v1 API موحّدة) — لا حاجة لأي تعديل على تلك الدالة.
 *
 * لا يفعل شيئًا إطلاقًا (بصمت) إن لم تُضبط إعدادات Firebase بعد في
 * .env.local، أو رفض المتصفح/المستخدم الإذن — نفس فلسفة
 * PushNotificationService في تطبيق الزبون: الميزة تتعطّل بهدوء، ولا
 * تكسر أي شيء آخر في اللوحة.
 *
 * ملاحظة مؤقتة (تشخيص): كل خطوة تطبع في Console بادئة "[Push]" — نفس
 * أسلوب تشخيص PHASE 11 في تطبيق الزبون، تُحذف بعد التأكد من نجاح
 * الميزة فعليًا على جهاز حقيقي.
 *
 * يُركَّب مرة واحدة في app/dashboard/layout.tsx (بعد التأكد من وجود
 * تاجر مسجَّل دخوله فعليًا).
 */

// حارس على مستوى الوحدة (module-level)، لا على مستوى المكوّن: في وضع
// التطوير، React Strict Mode يشغّل useEffect مرتين (mount → cleanup →
// mount) عمدًا لكشف الأخطاء. علم "ignore" المحلي يمنع فقط نتائج
// التشغيلة الأولى (setState) بعد كل await، لكنه لا يوقف نداءات
// الشبكة/IndexedDB التي بدأت فعلاً (register/getToken) — فتتسابق
// تشغيلتان حقيقيتان لـ getToken() في نفس اللحظة داخل Firebase SDK،
// وتتصادمان على نفس بيانات Installations/heartbeats المخزَّنة في
// IndexedDB. هذا هو السبب الحقيقي لخطأ "Headers: non ISO-8859-1 code
// point" المتقطّع (وليس أي حرف مخفي في الإعدادات كما ظننّا أولاً —
// تأكّدنا أن VAPID key وكل قيم firebaseConfig نظيفة). حارس مشترك على
// مستوى الوحدة يضمن أن التسجيل الفعلي (SW + getToken + حفظ التوكن) لا
// يُنفَّذ إلا مرة واحدة فعليًا مهما تكرّر mount للمكوّن.
let registerTokenPromise: Promise<void> | null = null;

async function registerToken(messaging: Messaging) {
  console.log("[Push] إذن الإشعارات الحالي:", Notification.permission);
  if (Notification.permission === "default") {
    const result = await Notification.requestPermission();
    console.log("[Push] نتيجة طلب الإذن:", result);
  }
  if (Notification.permission !== "granted") {
    console.log("[Push] توقّف: الإذن غير ممنوح");
    return;
  }

  let registration: ServiceWorkerRegistration;
  try {
    await navigator.serviceWorker.register("/firebase-messaging-sw.js");
    // register() يُرجع بمجرد إنشاء التسجيل، لكن الـ Service Worker قد
    // يكون لا يزال "installing" وليس "active" بعد — واستدعاء
    // getToken()/PushManager.subscribe() قبل التفعيل الكامل يفشل بخطأ
    // "no active Service Worker". navigator.serviceWorker.ready تنتظر
    // فعليًا حتى يصبح نشطًا.
    registration = await navigator.serviceWorker.ready;
    console.log("[Push] Service Worker أصبح نشطًا (ready) ✅");
  } catch (e) {
    console.error("[Push] فشل تسجيل/تفعيل Service Worker:", e);
    return;
  }

  const vapidKeyRaw = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;
  console.log("[Push] VAPID key موجود:", Boolean(vapidKeyRaw));
  if (!vapidKeyRaw) return;

  const vapidKey = cleanEnvValue(vapidKeyRaw, "vapidKey")!;

  let token: string | null = null;
  try {
    token = await getToken(messaging, {
      vapidKey,
      serviceWorkerRegistration: registration,
    });
    console.log("[Push] getToken نجحت، طول التوكن:", token?.length);
  } catch (e) {
    console.error("[Push] فشل getToken:", e);
    return;
  }
  if (!token) return;

  const supabase = createClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();
  console.log("[Push] المستخدم الحالي:", user?.id, userError);
  if (!user) return;

  const { error: updateError } = await supabase
    .from("users")
    .update({ fcm_token: token })
    .eq("id", user.id);

  if (updateError) {
    console.error("[Push] فشل حفظ التوكن في قاعدة البيانات:", updateError);
  } else {
    console.log("[Push] تم حفظ التوكن في قاعدة البيانات بنجاح ✅");
  }
}

export default function PushNotificationsSetup() {
  useEffect(() => {
    let unsubscribeForeground: (() => void) | undefined;
    let cancelled = false;

    async function setup() {
      console.log("[Push] بدء الإعداد");

      const messaging = await getMessagingInstance();
      console.log(
        "[Push] getMessagingInstance:",
        messaging ? "متوفرة" : "null (إعدادات ناقصة أو غير مدعومة)",
      );
      if (!messaging || cancelled) return;

      // اشتراك الإشعارات الأمامية (foreground): محلي وخفيف، آمن تمامًا
      // لإعادة تسجيله في كل mount — العنصر الوحيد الذي يحتاج حارسًا ضد
      // التكرار هو التسجيل الفعلي عبر الشبكة أدناه.
      unsubscribeForeground = onMessage(messaging, (payload) => {
        const title = payload.notification?.title ?? "إشعار جديد";
        const body = payload.notification?.body ?? "";
        if (Notification.permission === "granted") {
          new Notification(title, { body });
        }
      });

      if (!registerTokenPromise) {
        registerTokenPromise = registerToken(messaging);
      }
      await registerTokenPromise;
    }

    setup();

    return () => {
      cancelled = true;
      unsubscribeForeground?.();
    };
  }, []);

  return null;
}
