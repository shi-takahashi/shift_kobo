import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/staff.dart';
import '../models/shift.dart';

class TestDataHelper {
  static Future<void> initializeTestData() async {
    // リリースビルドではテストデータを作成しない
    if (!kDebugMode) return;

    // 移行完了済みの場合はテストデータを作成しない
    final prefs = await SharedPreferences.getInstance();
    final hasMigrated = prefs.getBool('has_migrated_to_firestore') ?? false;
    if (hasMigrated) {
      debugPrint('ℹ️ [TestDataHelper] 移行完了済みのためテストデータ作成をスキップ');
      return;
    }

    final staffBox = Hive.box<Staff>('staff');
    final shiftBox = Hive.box<Shift>('shifts');

    // スタッフデータが既に存在する場合はスキップ
    if (staffBox.isNotEmpty) {
      debugPrint('ℹ️ [TestDataHelper] 既存データがあるためテストデータ作成をスキップ');
      return;
    }

    debugPrint('🔧 [TestDataHelper] テストデータ作成開始');
    
    // テスト用スタッフデータ
    final testStaff = [
      Staff(
        id: 'staff_001',
        name: '田中 太郎',
        email: 'tanaka@example.com',
        phoneNumber: '090-1234-5678',
        isActive: true,
        preferredDaysOff: [7], // 日曜日
        maxShiftsPerMonth: 20,
        unavailableShiftTypes: ['夜勤'], // 夜勤不可
      ),
      Staff(
        id: 'staff_002',
        name: '佐藤 花子',
        email: 'sato@example.com',
        phoneNumber: '080-9876-5432',
        isActive: true,
        preferredDaysOff: [6, 7], // 土日
        maxShiftsPerMonth: 15,
        unavailableShiftTypes: [], // 全シフト可能
      ),
      Staff(
        id: 'staff_003',
        name: '鈴木 一郎',
        email: 'suzuki@example.com',
        phoneNumber: '070-1111-2222',
        isActive: true,
        preferredDaysOff: [1], // 月曜日
        maxShiftsPerMonth: 18,
        unavailableShiftTypes: ['早番', '夜勤'], // 早番・夜勤不可
      ),
      Staff(
        id: 'staff_004',
        name: '高橋 美咲',
        email: 'takahashi@example.com',
        phoneNumber: '090-3333-4444',
        isActive: true,
        preferredDaysOff: [3], // 水曜日
        maxShiftsPerMonth: 12,
        unavailableShiftTypes: ['夜勤'], // 夜勤不可
      ),
    ];
    
    // スタッフデータを保存
    for (final staff in testStaff) {
      await staffBox.put(staff.id, staff);
    }
    
    // テスト用シフトデータ（今月のシフト）
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final testShifts = <Shift>[];
    
    // 今月の最初の2週間にサンプルシフトを作成
    for (int day = 1; day <= 14; day++) {
      final shiftDate = DateTime(now.year, now.month, day);
      
      // 平日は複数人、土日は少なめ
      final staffCount = (shiftDate.weekday == 6 || shiftDate.weekday == 7) ? 1 : 2;
      
      for (int i = 0; i < staffCount && i < testStaff.length; i++) {
        // スタッフの休み希望を考慮
        if (testStaff[i].preferredDaysOff.contains(shiftDate.weekday)) {
          continue;
        }
        
        final shift = Shift(
          id: 'shift_${shiftDate.day}_$i',
          date: shiftDate,
          staffId: testStaff[i].id,
          shiftType: _getShiftTypeForDay(shiftDate, i),
          startTime: DateTime(shiftDate.year, shiftDate.month, shiftDate.day, 9 + i * 4, 0),
          endTime: DateTime(shiftDate.year, shiftDate.month, shiftDate.day, 17 + i * 2, 0),
        );
        
        testShifts.add(shift);
      }
    }
    
    // シフトデータを保存
    for (final shift in testShifts) {
      await shiftBox.put(shift.id, shift);
    }

    debugPrint('✅ [TestDataHelper] テストデータ作成完了（スタッフ: ${testStaff.length}件, シフト: ${testShifts.length}件）');
  }
  
  static String _getShiftTypeForDay(DateTime date, int staffIndex) {
    // 簡単なシフトタイプの割り当て
    if (date.weekday == 6 || date.weekday == 7) {
      return '休日勤務';
    } else {
      return staffIndex == 0 ? '早番' : '遅番';
    }
  }
}