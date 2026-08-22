import { initializeApp, getApps, type FirebaseApp } from "firebase/app";
import { getMessaging, isSupported, type Messaging } from "firebase/messaging";

/**
 * إعدادات Firebase — نفس مشروع Firebase المستخدَم لإشعارات تطبيقي
 * الزبون والموصّل (Android)، بتسجيل "تطبيق ويب" إضافي داخله. هذه القيم
 * عامة وليست سرًا (Firebase توثّق ذلك رسميًا، نفس مبدأ publishableKey في
 * Supabase) — الحماية الفعلية دائمًا من قواعد RLS في قاعدة البيانات،
 * وليس من إخفاء هذه القيم.
 */
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

let app: FirebaseApp | null = null;

function getFirebaseApp(): FirebaseApp | null {
  // لم تُضبط إعدادات Firebase بعد في .env.local — نرجع null بهدوء بدل
  // رمي استثناء، نفس فلسفة PushNotificationService في تطبيق الزبون
  // (الميزة تُعطَّل تلقائيًا حتى يُضبط Firebase، بدون كسر باقي اللوحة).
  if (!firebaseConfig.apiKey) return null;
  if (!app) {
    app = getApps()[0] ?? initializeApp(firebaseConfig);
  }
  return app;
}

/** null إن كانت المنصّة/المتصفح لا يدعم Web Push، أو الإعدادات ناقصة. */
export async function getMessagingInstance(): Promise<Messaging | null> {
  if (typeof window === "undefined") return null;

  const supported = await isSupported().catch(() => false);
  if (!supported) return null;

  const firebaseApp = getFirebaseApp();
  if (!firebaseApp) return null;

  return getMessaging(firebaseApp);
}
