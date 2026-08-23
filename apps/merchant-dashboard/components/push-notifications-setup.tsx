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
 * تكسر أي شيء آخر في اللوحة. الأخطاء الحقيقية (فشل تسجيل/حفظ) تُطبع في
 * Console عبر console.error فقط، بدون ضجيج تشخيصي لكل خطوة ناجحة —
 * مؤكَّد نجاح المسار الكامل على جهاز حقيقي (راجع commit history لتفاصيل
 * التشخيص إن احتجتها مستقبلاً: تسابق React Strict Mode + برنامج مضاد
 * فيروسات يعترض القيم الشبيهة بمفاتيح Google API، محلولان الآن).
 *
 * يُركَّب مرة واحدة في app/dashboard/layout.tsx (بعد التأكد من وجود
 * تاجر مسجَّل دخوله فعليًا).
 */

// حارس على مستوى الوحدة (module-level)، لا على مستوى المكوّن: React
// Strict Mode في وضع التطوير يشغّل useEffect مرتين (mount → cleanup →
// mount) عمدًا، وهذا يضمن أن التسجيل الفعلي عبر الشبكة (SW + getToken
// + حفظ التوكن) لا يُنفَّذ إلا مرة واحدة فعليًا مهما تكرّر mount
// للمكوّن — نداءان متزامنان لـ getToken() كانا يتصادمان على بيانات
// Firebase Installations المخزَّنة محليًا (IndexedDB).
let registerTokenPromise: Promise<void> | null = null;

async function registerToken(messaging: Messaging) {
  if (Notification.permission === "default") {
    await Notification.requestPermission();
  }
  if (Notification.permission !== "granted") return;

  let registration: ServiceWorkerRegistration;
  try {
    await navigator.serviceWorker.register("/firebase-messaging-sw.js");
    // register() يُرجع بمجرد إنشاء التسجيل، لكن الـ Service Worker قد
    // يكون لا يزال "installing" وليس "active" بعد — واستدعاء
    // getToken()/PushManager.subscribe() قبل التفعيل الكامل يفشل بخطأ
    // "no active Service Worker". navigator.serviceWorker.ready تنتظر
    // فعليًا حتى يصبح نشطًا.
    registration = await navigator.serviceWorker.ready;
  } catch (e) {
    console.error("[Push] فشل تسجيل/تفعيل Service Worker:", e);
    return;
  }

  const vapidKeyRaw = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;
  if (!vapidKeyRaw) return;
  const vapidKey = cleanEnvValue(vapidKeyRaw, "vapidKey")!;

  let token: string | null = null;
  try {
    token = await getToken(messaging, { vapidKey, serviceWorkerRegistration: registration });
  } catch (e) {
    console.error("[Push] فشل getToken:", e);
    return;
  }
  if (!token) return;

  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return;

  const { error: updateError } = await supabase.from("users").update({ fcm_token: token }).eq("id", user.id);
  if (updateError) {
    console.error("[Push] فشل حفظ التوكن في قاعدة البيانات:", updateError);
  }
}

export default function PushNotificationsSetup() {
  useEffect(() => {
    let unsubscribeForeground: (() => void) | undefined;
    let cancelled = false;

    async function setup() {
      const messaging = await getMessagingInstance();
      if (!messaging || cancelled) return;

      // اشتراك الإشعارات الأمامية (foreground): محلي وخفيف، آمن تمامًا
      // لإعادة تسجيله في كل mount — العنصر الوحيد الذي يحتاج حارسًا ضد
      // التكرار هو التسجيل الفعلي عبر الشبكة أعلاه.
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
