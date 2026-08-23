// يولّد public/firebase-messaging-sw.js وقت البناء (على سيرفر Vercel،
// وليس محليًا) من نفس متغيرات البيئة المستخدَمة في lib/firebase.ts.
//
// لماذا سكربت بناء وليس ملفًا ثابتًا في public/؟ لأن هذا الملف مُستثنى
// من git عمدًا (راجع .gitignore + public/firebase-messaging-sw.js.example)
// — كان يُنشأ يدويًا محليًا فقط أثناء التطوير على localhost. عند النشر
// على Vercel عبر GitHub، الملف المحلي لا يصل إطلاقًا (git لا يعرفه)،
// فيفشل تسجيل الـ Service Worker بصمت (404) ولا يُحفظ أي fcm_token —
// هذا بالضبط ما حدث فعليًا أول نشر (خطأ حقيقي اكتُشف باختبار حي على
// جهاز هاتف حقيقي). الحل: توليده هنا من Environment Variables المضبوطة
// في Vercel، في كل بناء — بدون الحاجة لتغيير .gitignore أو كتابة أي
// سرّ داخل git (وأي حال هذه القيم عامة أصلًا، راجع تعليق lib/firebase.ts).
const fs = require("node:fs");
const path = require("node:path");

function decodeApiKey() {
  const b64 = process.env.NEXT_PUBLIC_FIREBASE_API_KEY_B64?.trim();
  if (b64) {
    try {
      return Buffer.from(b64, "base64").toString("utf-8").trim();
    } catch {
      // نتجاهل ونكمل بالقيمة النصية الاحتياطية أدناه.
    }
  }
  return process.env.NEXT_PUBLIC_FIREBASE_API_KEY?.trim();
}

const config = {
  apiKey: decodeApiKey(),
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN?.trim(),
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID?.trim(),
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET?.trim(),
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID?.trim(),
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID?.trim(),
};

const outPath = path.join(__dirname, "..", "public", "firebase-messaging-sw.js");

// نفس فلسفة lib/firebase.ts: إعدادات Firebase غير مضبوطة → تعطيل هادئ
// (لا نكتب ملفًا فارغًا/مكسورًا يفشل تسجيله لاحقًا بخطأ مربك)، بدون
// فشل البناء نفسه — الميزة اختيارية أصلًا (راجع .env.local.example).
if (!config.apiKey) {
  console.log("[generate-sw] إعدادات Firebase غير مضبوطة — تخطّي توليد firebase-messaging-sw.js");
  process.exit(0);
}

const content = `// تم توليده تلقائيًا وقت البناء من scripts/generate-sw.js — لا تُعدّله يدويًا.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp(${JSON.stringify(config, null, 2)});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'إشعار جديد';
  const options = {
    body: payload.notification?.body ?? '',
    icon: '/icons/icon-192.png',
  };
  self.registration.showNotification(title, options);
});
`;

fs.writeFileSync(outPath, content, "utf-8");
console.log(`[generate-sw] تم توليد ${outPath}`);
