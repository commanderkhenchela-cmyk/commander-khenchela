/**
 * يضغط صورة فـ المتصفّح قبل رفعها لـ Supabase Storage — عبر canvas،
 * بدل رفع الملف الأصلي كما هو. خطة Supabase المجانية لا تدعم Storage
 * Image Transformations (تصغير عند الطلب من الخادم)، فهذا هو المكان
 * الوحيد الممكن لتفادي إهدار Cached Egress الشهري — كل مشاهدة لاحقة
 * لنفس الصورة تُحمِّل الحجم المضغوط بدل الأصلي الكامل.
 *
 * لا يرمي أبدًا — أي فشل يُرجع الملف الأصلي دون تعديل، فلا يعطّل الرفع
 * بسبب تحسين اختياري.
 */
export async function compressImage(
  file: File,
  { maxDimension = 1200, quality = 0.82 }: { maxDimension?: number; quality?: number } = {},
): Promise<File> {
  if (!file.type.startsWith("image/")) return file;

  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    return file;
  }

  const scale = Math.min(1, maxDimension / Math.max(bitmap.width, bitmap.height));
  const targetWidth = Math.max(1, Math.round(bitmap.width * scale));
  const targetHeight = Math.max(1, Math.round(bitmap.height * scale));

  const canvas = document.createElement("canvas");
  canvas.width = targetWidth;
  canvas.height = targetHeight;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    bitmap.close();
    return file;
  }

  ctx.drawImage(bitmap, 0, 0, targetWidth, targetHeight);
  bitmap.close();

  // PNG تبقى PNG (تحافظ على الشفافية — مهمّة لشعار التطبيق بخلفية
  // شفافة)؛ أي صيغة أخرى تُحوَّل لـ JPEG، أخفّ بكثير.
  const outputType = file.type === "image/png" ? "image/png" : "image/jpeg";
  const outputExt = outputType === "image/png" ? "png" : "jpg";

  const blob = await new Promise<Blob | null>((resolve) =>
    canvas.toBlob(resolve, outputType, outputType === "image/jpeg" ? quality : undefined),
  );
  if (!blob || blob.size >= file.size) return file;

  const newName = file.name.replace(/\.[^./]+$/, "") + "." + outputExt;
  return new File([blob], newName, { type: outputType });
}
