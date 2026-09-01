import '../l10n/app_localizations.dart';

/// نموذج طلب "حرفيون" — راجع migration 20260907000000_craftsman_requests.
/// V1 مطابق لبداية التوصيل نفسها فـ هذا المشروع: لا حساب حرفي بعد،
/// الإدارة تربط الطلب يدويًا ببيانات تواصل حرّة (اسم/هاتف) بعد المراجعة.
class CraftsmanRequest {
  final String id;
  final String craftType;
  final String description;
  final String status;
  final String? assignedCraftsmanName;
  final String? assignedCraftsmanPhone;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;

  const CraftsmanRequest({
    required this.id,
    required this.craftType,
    required this.description,
    required this.status,
    required this.createdAt,
    this.assignedCraftsmanName,
    this.assignedCraftsmanPhone,
    this.assignedAt,
    this.completedAt,
  });

  factory CraftsmanRequest.fromMap(Map<String, dynamic> map) {
    return CraftsmanRequest(
      id: map['id'] as String,
      craftType: map['craft_type'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      assignedCraftsmanName: map['assigned_craftsman_name'] as String?,
      assignedCraftsmanPhone: map['assigned_craftsman_phone'] as String?,
      assignedAt: map['assigned_at'] == null
          ? null
          : DateTime.parse(map['assigned_at'] as String),
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
    );
  }

  static const List<String> craftTypes = [
    'plumber',
    'electrician',
    'painter',
    'carpenter',
    'locksmith',
    'ac_technician',
    'general',
  ];

  static String craftTypeLabel(String craftType, AppLocalizations l10n) {
    switch (craftType) {
      case 'plumber':
        return l10n.craftTypePlumber;
      case 'electrician':
        return l10n.craftTypeElectrician;
      case 'painter':
        return l10n.craftTypePainter;
      case 'carpenter':
        return l10n.craftTypeCarpenter;
      case 'locksmith':
        return l10n.craftTypeLocksmith;
      case 'ac_technician':
        return l10n.craftTypeAcTechnician;
      case 'general':
        return l10n.craftTypeGeneral;
      default:
        return craftType;
    }
  }

  static String statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.craftsmanRequestStatusPending;
      case 'assigned':
        return l10n.craftsmanRequestStatusAssigned;
      case 'completed':
        return l10n.craftsmanRequestStatusCompleted;
      case 'cancelled':
        return l10n.craftsmanRequestStatusCancelled;
      default:
        return status;
    }
  }
}
