import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/staff.dart';
import '../models/shift.dart';
import '../models/shift_constraint.dart';
import '../models/shift_time_setting.dart';

/// データ移行の結果
class MigrationResult {
  final int staffCount;
  final int shiftsCount;
  final int constraintsCount;
  final int shiftTimeSettingsCount;
  final int monthlyRequirementsCount;
  final bool success;
  final String? errorMessage;

  MigrationResult({
    required this.staffCount,
    required this.shiftsCount,
    required this.constraintsCount,
    required this.shiftTimeSettingsCount,
    required this.monthlyRequirementsCount,
    required this.success,
    this.errorMessage,
  });

  int get totalCount =>
      staffCount +
      shiftsCount +
      constraintsCount +
      shiftTimeSettingsCount +
      monthlyRequirementsCount;
}

/// Hive → Firestoreデータ移行サービス
class MigrationService {
  static final _firestore = FirebaseFirestore.instance;

  /// Hiveからデータを読み込んでFirestoreに移行
  static Future<MigrationResult> migrateToFirestore(String teamId) async {
    int staffCount = 0;
    int shiftsCount = 0;
    int constraintsCount = 0;
    int shiftTimeSettingsCount = 0;
    int monthlyRequirementsCount = 0;

    try {
      print('🚀 データ移行開始: teamId=$teamId');

      // Hiveボックスを開く（既にmain.dartで開いているので、getで取得）
      final staffBox = Hive.box<Staff>('staff');
      final shiftsBox = Hive.box<Shift>('shifts');
      final constraintsBox = Hive.box<ShiftConstraint>('constraints');
      final shiftTimeBox = Hive.box<ShiftTimeSetting>('shift_time_settings');

      print('📦 Hiveデータ件数:');
      print('  スタッフ: ${staffBox.length}件');
      print('  シフト: ${shiftsBox.length}件');
      print('  制約: ${constraintsBox.length}件');
      print('  シフト時間設定: ${shiftTimeBox.length}件');

      // Firestoreバッチ処理を作成
      final batch = _firestore.batch();

      // 1. スタッフデータの移行
      for (var staff in staffBox.values) {
        final docRef = _firestore
            .collection('teams')
            .doc(teamId)
            .collection('staff')
            .doc(staff.id);

        batch.set(docRef, {
          'name': staff.name,
          'phoneNumber': staff.phoneNumber,
          'email': staff.email,
          'maxShiftsPerMonth': staff.maxShiftsPerMonth,
          'isActive': staff.isActive,
          'preferredDaysOff': staff.preferredDaysOff,
          'unavailableShiftTypes': staff.unavailableShiftTypes,
          'specificDaysOff': staff.specificDaysOff,
          'createdAt': FieldValue.serverTimestamp(),
        });
        staffCount++;
      }

      // 2. シフトデータの移行
      for (var shift in shiftsBox.values) {
        final docRef = _firestore
            .collection('teams')
            .doc(teamId)
            .collection('shifts')
            .doc(shift.id);

        batch.set(docRef, {
          'date': Timestamp.fromDate(shift.date),
          'staffId': shift.staffId,
          'shiftType': shift.shiftType,
          'startTime': Timestamp.fromDate(shift.startTime),
          'endTime': Timestamp.fromDate(shift.endTime),
          'createdAt': FieldValue.serverTimestamp(),
        });
        shiftsCount++;
      }

      // 3. 制約データの移行
      for (var constraint in constraintsBox.values) {
        final docRef = _firestore
            .collection('teams')
            .doc(teamId)
            .collection('constraints')
            .doc(constraint.id);

        batch.set(docRef, {
          'staffId': constraint.staffId,
          'date': Timestamp.fromDate(constraint.date),
          'isAvailable': constraint.isAvailable,
          'reason': constraint.reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
        constraintsCount++;
      }

      // 4. シフト時間設定の移行
      for (var i = 0; i < shiftTimeBox.length; i++) {
        final setting = shiftTimeBox.getAt(i);
        if (setting == null) continue;

        final docRef = _firestore
            .collection('teams')
            .doc(teamId)
            .collection('shift_time_settings')
            .doc(); // 自動ID生成

        batch.set(docRef, {
          'shiftType': setting.shiftType.index,
          'customName': setting.customName,
          'startTime': setting.startTime,
          'endTime': setting.endTime,
          'isActive': setting.isActive,
          'createdAt': FieldValue.serverTimestamp(),
        });
        shiftTimeSettingsCount++;
      }

      // バッチ実行（一括書き込み）
      print('💾 Firestoreへバッチ書き込み開始...');
      await batch.commit();
      print('✅ バッチ書き込み完了');

      // 5. SharedPreferencesから月間シフト設定を移行
      final prefs = await SharedPreferences.getInstance();
      final shiftRequirements = <String, int>{};

      for (String key in prefs.getKeys()) {
        if (key.startsWith('shift_requirement_')) {
          final shiftType = key.replaceFirst('shift_requirement_', '');
          shiftRequirements[shiftType] = prefs.getInt(key) ?? 0;
        }
      }

      if (shiftRequirements.isNotEmpty) {
        await _firestore
            .collection('teams')
            .doc(teamId)
            .collection('settings')
            .doc('monthly_requirements')
            .set({
          ...shiftRequirements,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        monthlyRequirementsCount = shiftRequirements.length;
      }

      print('🎉 データ移行完了:');
      print('  スタッフ: $staffCount件');
      print('  シフト: $shiftsCount件');
      print('  制約: $constraintsCount件');
      print('  シフト時間設定: $shiftTimeSettingsCount件');
      print('  月間設定: $monthlyRequirementsCount件');

      return MigrationResult(
        staffCount: staffCount,
        shiftsCount: shiftsCount,
        constraintsCount: constraintsCount,
        shiftTimeSettingsCount: shiftTimeSettingsCount,
        monthlyRequirementsCount: monthlyRequirementsCount,
        success: true,
      );
    } catch (e, stackTrace) {
      print('❌ データ移行エラー: $e');
      print('スタックトレース: $stackTrace');

      return MigrationResult(
        staffCount: staffCount,
        shiftsCount: shiftsCount,
        constraintsCount: constraintsCount,
        shiftTimeSettingsCount: shiftTimeSettingsCount,
        monthlyRequirementsCount: monthlyRequirementsCount,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 移行後にHiveデータを削除
  static Future<void> clearHiveData() async {
    try {
      print('🗑️ Hiveデータ削除開始...');

      final staffBox = Hive.box<Staff>('staff');
      final shiftsBox = Hive.box<Shift>('shifts');
      final constraintsBox = Hive.box<ShiftConstraint>('constraints');

      await staffBox.clear();
      await shiftsBox.clear();
      await constraintsBox.clear();

      print('✅ Hiveデータ削除完了');
    } catch (e) {
      print('❌ Hiveデータ削除エラー: $e');
      // エラーでも続行（移行済みなので問題ない）
    }
  }
}
