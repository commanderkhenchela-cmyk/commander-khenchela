import type { OrderStatus } from "./types";

export type StatusTone = "primary" | "warning" | "error" | "neutral";

/**
 * خريطة لون واحدة موحّدة لحالة الطلب — تحل محل تطبيقين كانا متعارضين:
 * StatusBadge المحلية في orders/page.tsx (delivered=primary،
 * cancelled/rejected=error، وكل ما عداهما warning) مقابل نص عادي بلا أي
 * تمييز لون إطلاقًا في orders/[id]/page.tsx. القيم هنا هي *نفسها بالضبط*
 * منطق orders/page.tsx الأصلي — لا لون جديد، فقط توحيد مكان تعريفه
 * وتطبيقه في الصفحتين معًا. لا علاقة لهذا الملف بـ OrderStatus أو
 * ORDER_STATUS_LABELS نفسيهما (يبقيان كما هما في lib/types.ts).
 */
export const ORDER_STATUS_TONE: Record<OrderStatus, StatusTone> = {
  pending: "warning",
  confirmed: "warning",
  preparing: "warning",
  ready_for_pickup: "warning",
  picked_up: "warning",
  out_for_delivery: "warning",
  delivered: "primary",
  cancelled: "error",
  rejected: "error",
};
