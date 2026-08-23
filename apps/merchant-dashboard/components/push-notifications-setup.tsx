"use client";

import { useEffect } from "react";
import { getToken, onMessage } from "firebase/messaging";
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
export default function PushNotificationsSetup() {
  useEffect(() => {
    let ignore = false;
    let unsubscribeForeground: (() => void) | undefined;

    async function setup() {
      console.log("[Push] بدء الإعداد");

      const messaging = await getMessagingInstance();
      console.log("[Push] getMessagingInstance:", messaging ? "متوفرة" : "null (إعدادات ناقصة أو غير مدعومة)");
      if (!messaging || ignore) return;

      unsubscribeForeground = onMessage(messaging, (payload) => {
        const title = payload.notification?.title ?? "إشعار جديد";
        const body = payload.notification?.body ?? "";
        if (Notification.permission === "granted") {
          new Notification(title, { body });
        }
      });

      console.log("[Push] إذن الإشعارات الحالي:", Notification.permission);
      if (Notification.permission === "default") {
        const result = await Notification.requestPermission();
        console.log("[Push] نتيجة طلب الإذن:", result);
      }
      if (Notification.permission !== "granted" || ignore) {
        console.log("[Push] توقّف: الإذن غير ممنوح");
        return;
      }

      let registration: ServiceWorkerRegistration | null = null;
      try {
        registration = await navigator.serviceWorker.register("/firebase-messaging-sw.js");
        console.log("[Push] تسجيل Service Worker نجح:", registration.scope);
      } catch (e) {
        console.error("[Push] فشل تسجيل Service Worker:", e);
        return;
      }
      if (!registration || ignore) return;

      const vapidKeyRaw = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;
      console.log("[Push] VAPID key موجود:", Boolean(vapidKeyRaw));
      if (!vapidKeyRaw) return;

      // نفس التنظيف المطبَّق على firebaseConfig (trim + إزالة أحرف
      // Unicode "Format" غير المرئية) — هذا هو المُشتبه به الرئيسي
      // لخطأ "Headers: non ISO-8859-1 code point" لأنه القيمة الوحيدة
      // التي تُلصق يدويًا بشكل منفصل عن باقي الإعدادات.
      const vapidKey = cleanEnvValue(vapidKeyRaw, "vapidKey")!;
      const badChars = [...vapidKey]
        .map((ch, i) => ({ ch, i, code: ch.codePointAt(0)! }))
        .filter((x) => x.code > 255);
      if (badChars.length > 0) {
        console.error("[Push] أحرف غير صالحة ما زالت داخل VAPID key بعد التنظيف:", badChars);
      }
      console.log(
        "[Push] طول VAPID key بعد التنظيف:",
        vapidKey.length,
        "(الأصلي:",
        vapidKeyRaw.length,
        ")",
      );

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
      if (!token || ignore) return;

      const supabase = createClient();
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser();
      console.log("[Push] المستخدم الحالي:", user?.id, userError);
      if (!user || ignore) return;

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

    setup();

    return () => {
      ignore = true;
      unsubscribeForeground?.();
    };
  }, []);

  return null;
}
