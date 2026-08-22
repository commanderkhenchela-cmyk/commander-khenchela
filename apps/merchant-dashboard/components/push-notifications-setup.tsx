"use client";

import { useEffect } from "react";
import { getToken, onMessage } from "firebase/messaging";
import { getMessagingInstance } from "@/lib/firebase";
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
 * يُركَّب مرة واحدة في app/dashboard/layout.tsx (بعد التأكد من وجود
 * تاجر مسجَّل دخوله فعليًا).
 */
export default function PushNotificationsSetup() {
  useEffect(() => {
    let ignore = false;
    let unsubscribeForeground: (() => void) | undefined;

    async function setup() {
      const messaging = await getMessagingInstance();
      if (!messaging || ignore) return;

      // إشعار وارد والتبويب مفتوح فعليًا (foreground) — Firebase لا تعرض
      // إشعار النظام تلقائيًا في هذه الحالة (نفس الأمر بالضبط في تطبيق
      // الزبون)، فنعرضه يدويًا.
      unsubscribeForeground = onMessage(messaging, (payload) => {
        const title = payload.notification?.title ?? "إشعار جديد";
        const body = payload.notification?.body ?? "";
        if (Notification.permission === "granted") {
          new Notification(title, { body });
        }
      });

      if (Notification.permission === "default") {
        await Notification.requestPermission();
      }
      if (Notification.permission !== "granted" || ignore) return;

      const registration = await navigator.serviceWorker
        .register("/firebase-messaging-sw.js")
        .catch(() => null);
      if (!registration || ignore) return;

      const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;
      if (!vapidKey) return;

      const token = await getToken(messaging, {
        vapidKey,
        serviceWorkerRegistration: registration,
      }).catch(() => null);
      if (!token || ignore) return;

      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user || ignore) return;

      await supabase.from("users").update({ fcm_token: token }).eq("id", user.id);
    }

    setup();

    return () => {
      ignore = true;
      unsubscribeForeground?.();
    };
  }, []);

  return null;
}
