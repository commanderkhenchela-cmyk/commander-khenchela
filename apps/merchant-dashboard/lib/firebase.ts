import { initializeApp, getApps, type FirebaseApp } from "firebase/app";
import { getMessaging, isSupported, type Messaging } from "firebase/messaging";

/**
 * إعدادات Firebase — نفس مشروع Firebase المستخدَم لإشعارات تطبيقي
 * الزبون والموصّل (Android)، بتسجيل "تطبيق ويب" إضافي داخله. هذه القيم
 * عامة وليست سرًا (Firebase توثّق ذلك رسميًا، نفس مبدأ publishableKey في
 * Supabase) — الحماية الفعلية دائمًا من قواعد RLS في قاعدة البيانات،
 * وليس من إخفاء هذه القيم.
 */
// .trim() وحده غير كافٍ: لا يزيل أحرف "التنسيق" غير المرئية (Unicode
// category Cf — مثل علامات اتجاه النص RLM/LRM، أو BOM، أو Zero-Width
// Space) التي قد تنضاف بالخطأ عند اللصق اليدوي في بيئة عربية RTL على
// Windows، ولا تظهر بصريًا في أي محرر نصوص. أي حرف من هذه الفئة داخل
// قيمة تُستخدم لاحقًا في بناء HTTP Header يكسر Headers() في المتصفح
// برسالة غامضة: "String contains non ISO-8859-1 code point". ننظّفها
// من المصدر هنا بدل تشخيصها كل مرة.
export function cleanEnvValue(raw: string | undefined, label: string): string | undefined {
  if (!raw) return raw;
  const trimmed = raw.trim();
  const cleaned = trimmed.replace(/\p{Cf}/gu, "");
  if (cleaned !== trimmed && typeof window !== "undefined") {
    console.warn(
      `[Push] تنبيه: تمت إزالة أحرف غير مرئية من القيمة "${label}" (الطول قبل: ${trimmed.length}, بعد: ${cleaned.length})`,
    );
  }
  return cleaned;
}

const firebaseConfig = {
  apiKey: cleanEnvValue(process.env.NEXT_PUBLIC_FIREBASE_API_KEY, "apiKey"),
  authDomain: cleanEnvValue(process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN, "authDomain"),
  projectId: cleanEnvValue(process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID, "projectId"),
  storageBucket: cleanEnvValue(process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET, "storageBucket"),
  messagingSenderId: cleanEnvValue(
    process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    "messagingSenderId",
  ),
  appId: cleanEnvValue(process.env.NEXT_PUBLIC_FIREBASE_APP_ID, "appId"),
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
