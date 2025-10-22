/// 休み希望承認リクエストモデル
///
/// スタッフの休み希望を管理者が承認・却下するための申請データ
class ConstraintRequest {
  /// 申請ID（Firestore自動生成）
  final String id;

  /// 申請者のスタッフID
  final String staffId;

  /// 申請者のユーザーID（AppUser.uid）
  final String userId;

  /// 申請タイプ（"specificDay" | "weekday" | "shiftType"）
  final String requestType;

  /// 特定日の休み希望（requestType == "specificDay"の場合）
  final DateTime? specificDate;

  /// 曜日の休み希望（requestType == "weekday"の場合、1-7: 月-日）
  final int? weekday;

  /// シフトタイプの勤務不可申請（requestType == "shiftType"の場合）
  final String? shiftType;

  /// 申請ステータス（"pending" | "approved" | "rejected"）
  final String status;

  /// 承認者のユーザーID（AppUser.uid）
  final String? approvedBy;

  /// 承認日時
  final DateTime? approvedAt;

  /// 却下理由
  final String? rejectedReason;

  /// 作成日時
  final DateTime createdAt;

  /// 更新日時
  final DateTime updatedAt;

  // 定数：申請タイプ
  static const String typeSpecificDay = 'specificDay';
  static const String typeWeekday = 'weekday';
  static const String typeShiftType = 'shiftType';

  // 定数：ステータス
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  ConstraintRequest({
    required this.id,
    required this.staffId,
    required this.userId,
    required this.requestType,
    this.specificDate,
    this.weekday,
    this.shiftType,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectedReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Firestore用のJSON形式に変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'userId': userId,
      'requestType': requestType,
      'specificDate': specificDate?.toIso8601String(),
      'weekday': weekday,
      'shiftType': shiftType,
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectedReason': rejectedReason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// FirestoreのJSONから変換
  factory ConstraintRequest.fromJson(Map<String, dynamic> json) {
    return ConstraintRequest(
      id: json['id'] as String,
      staffId: json['staffId'] as String,
      userId: json['userId'] as String,
      requestType: json['requestType'] as String,
      specificDate: json['specificDate'] != null
          ? DateTime.parse(json['specificDate'] as String)
          : null,
      weekday: json['weekday'] as int?,
      shiftType: json['shiftType'] as String?,
      status: json['status'] as String,
      approvedBy: json['approvedBy'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      rejectedReason: json['rejectedReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// コピーメソッド（一部のフィールドを更新する際に使用）
  ConstraintRequest copyWith({
    String? id,
    String? staffId,
    String? userId,
    String? requestType,
    DateTime? specificDate,
    int? weekday,
    String? shiftType,
    String? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConstraintRequest(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      userId: userId ?? this.userId,
      requestType: requestType ?? this.requestType,
      specificDate: specificDate ?? this.specificDate,
      weekday: weekday ?? this.weekday,
      shiftType: shiftType ?? this.shiftType,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedReason: rejectedReason ?? this.rejectedReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ConstraintRequest(id: $id, staffId: $staffId, requestType: $requestType, status: $status)';
  }
}
