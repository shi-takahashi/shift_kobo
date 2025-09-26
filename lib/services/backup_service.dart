import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/staff.dart';
import '../models/shift.dart';
import '../models/shift_constraint.dart';
import '../models/shift_time_setting.dart';

class BackupService {
  static const String backupFilePrefix = 'shift_kobo_backup_';
  static const String backupFileExtension = '.json';

  /// 全データのバックアップを作成
  static Future<Map<String, dynamic>> createBackupData() async {
    try {
      print('バックアップ開始...');
      
      // Hiveボックスからデータを取得
      print('Hiveボックスを開いています...');
      final staffBox = await Hive.openBox<Staff>('staff');
      print('スタッフボックス: ${staffBox.length}件');
      
      final shiftsBox = await Hive.openBox<Shift>('shifts');
      print('シフトボックス: ${shiftsBox.length}件');
      
      final constraintsBox = await Hive.openBox<ShiftConstraint>('constraints');
      print('制約ボックス: ${constraintsBox.length}件');
      
      final shiftTimeBox = await Hive.openBox<ShiftTimeSetting>('shift_time_settings');
      print('シフト時間設定ボックス: ${shiftTimeBox.length}件');

      // SharedPreferencesからデータを取得
      print('SharedPreferencesを取得中...');
      final prefs = await SharedPreferences.getInstance();
      final shiftRequirements = <String, int>{};
      
      // SharedPreferencesから月間シフト設定を取得
      for (String key in prefs.getKeys()) {
        if (key.startsWith('shift_requirement_')) {
          final shiftType = key.replaceFirst('shift_requirement_', '');
          shiftRequirements[shiftType] = prefs.getInt(key) ?? 0;
        }
      }
      print('月間シフト設定: ${shiftRequirements.length}件');

      // バックアップデータの構築
      print('バックアップデータを構築中...');
      final backupData = {
        'version': '1.0.0',
        'created_at': DateTime.now().toIso8601String(),
        'app_name': 'シフト工房',
        'data': {
          'staff': staffBox.values.map((staff) {
            try {
              return _staffToJson(staff);
            } catch (e) {
              print('スタッフデータ変換エラー: $e');
              rethrow;
            }
          }).toList(),
          'shifts': shiftsBox.values.map((shift) {
            try {
              return _shiftToJson(shift);
            } catch (e) {
              print('シフトデータ変換エラー: $e');
              rethrow;
            }
          }).toList(),
          'constraints': constraintsBox.values.map((constraint) {
            try {
              return _constraintToJson(constraint);
            } catch (e) {
              print('制約データ変換エラー: $e');
              rethrow;
            }
          }).toList(),
          'shift_time_settings': shiftTimeBox.values.map((setting) {
            try {
              return _shiftTimeSettingToJson(setting);
            } catch (e) {
              print('シフト時間設定変換エラー: $e');
              rethrow;
            }
          }).toList(),
          'shift_requirements': shiftRequirements,
        },
        'statistics': {
          'staff_count': staffBox.length,
          'shifts_count': shiftsBox.length,
          'constraints_count': constraintsBox.length,
          'shift_time_settings_count': shiftTimeBox.length,
        },
      };

      print('バックアップデータ構築完了');
      return backupData;
    } catch (e, stackTrace) {
      print('バックアップエラー: $e');
      print('スタックトレース: $stackTrace');
      throw Exception('バックアップデータの作成に失敗しました: $e');
    }
  }

  /// バックアップファイルを作成して保存
  static Future<String?> saveBackupToFile() async {
    try {
      final backupData = await createBackupData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      
      // ユーザーが保存先を選択
      final timestamp = DateTime.now().toIso8601String().split('T')[0].replaceAll('-', '');
      final fileName = '$backupFilePrefix$timestamp$backupFileExtension';
      
      // Android/iOSではbytesパラメータが必要
      final bytes = utf8.encode(jsonString);
      
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'バックアップファイルの保存先を選択',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      
      if (outputFile != null) {
        return outputFile;
      }
      
      return null; // ユーザーがキャンセルした場合
    } catch (e) {
      throw Exception('バックアップファイルの保存に失敗しました: $e');
    }
  }

  /// バックアップファイルを共有
  static Future<String?> shareBackupFile() async {
    try {
      // Android/iOS用：ユーザーが保存先を選択
      final filePath = await saveBackupToFile();
      
      if (filePath != null) {
        print('バックアップ完了: $filePath');
        return filePath;
      } else {
        print('保存がキャンセルされました');
        return null; // キャンセルの場合はnullを返す
      }
    } catch (e, stackTrace) {
      print('バックアップ共有エラー: $e');
      print('スタックトレース: $stackTrace');
      throw Exception('バックアップファイルの共有に失敗しました: $e');
    }
  }


  /// バックアップファイルを選択
  static Future<String?> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'バックアップファイルを選択',
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.first.path;
      }
      
      return null;
    } catch (e) {
      throw Exception('ファイルの選択に失敗しました: $e');
    }
  }

  /// バックアップファイルから復元
  static Future<void> restoreFromFile(String filePath, {bool overwrite = false}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('バックアップファイルが見つかりません');
      }

      final jsonString = await file.readAsString();
      final backupData = json.decode(jsonString) as Map<String, dynamic>;

      // バックアップデータの検証
      if (!_validateBackupData(backupData)) {
        throw Exception('無効なバックアップファイルです');
      }

      final data = backupData['data'] as Map<String, dynamic>;

      // Hiveボックスを開く
      final staffBox = await Hive.openBox<Staff>('staff');
      final shiftsBox = await Hive.openBox<Shift>('shifts');
      final constraintsBox = await Hive.openBox<ShiftConstraint>('constraints');
      final shiftTimeBox = await Hive.openBox<ShiftTimeSetting>('shift_time_settings');

      if (overwrite) {
        // 既存データをクリア
        await staffBox.clear();
        await shiftsBox.clear();
        await constraintsBox.clear();
        await shiftTimeBox.clear();
      }

      // スタッフデータの復元
      if (data['staff'] != null) {
        final staffList = data['staff'] as List;
        for (var staffJson in staffList) {
          final staff = _staffFromJson(staffJson as Map<String, dynamic>);
          await staffBox.put(staff.id, staff);
        }
      }

      // シフトデータの復元
      if (data['shifts'] != null) {
        final shiftsList = data['shifts'] as List;
        for (var shiftJson in shiftsList) {
          final shift = _shiftFromJson(shiftJson as Map<String, dynamic>);
          await shiftsBox.put(shift.id, shift);
        }
      }

      // 制約データの復元
      if (data['constraints'] != null) {
        final constraintsList = data['constraints'] as List;
        for (var constraintJson in constraintsList) {
          final constraint = _constraintFromJson(constraintJson as Map<String, dynamic>);
          await constraintsBox.put(constraint.id, constraint);
        }
      }

      // シフト時間設定の復元
      if (data['shift_time_settings'] != null) {
        final settingsList = data['shift_time_settings'] as List;
        for (var settingJson in settingsList) {
          final setting = _shiftTimeSettingFromJson(settingJson as Map<String, dynamic>);
          await shiftTimeBox.add(setting);
        }
      }

      // SharedPreferencesの復元
      if (data['shift_requirements'] != null) {
        final prefs = await SharedPreferences.getInstance();
        final requirements = data['shift_requirements'] as Map<String, dynamic>;
        
        for (var entry in requirements.entries) {
          await prefs.setInt('shift_requirement_${entry.key}', entry.value as int);
        }
      }

      print('復元完了 - 統計:');
      print('  スタッフ: ${data['staff']?.length ?? 0}件');
      print('  シフト: ${data['shifts']?.length ?? 0}件');
      print('  制約: ${data['constraints']?.length ?? 0}件');
      print('  シフト時間設定: ${data['shift_time_settings']?.length ?? 0}件');
      print('  月間設定: ${data['shift_requirements']?.length ?? 0}件');

    } catch (e) {
      throw Exception('データの復元に失敗しました: $e');
    }
  }

  /// バックアップデータの検証
  static bool _validateBackupData(Map<String, dynamic> data) {
    try {
      // 必須フィールドの確認
      if (!data.containsKey('version') || 
          !data.containsKey('created_at') || 
          !data.containsKey('data')) {
        return false;
      }

      final dataSection = data['data'] as Map<String, dynamic>;
      
      // データセクションの基本構造確認
      return dataSection.containsKey('staff') &&
             dataSection.containsKey('shifts') &&
             dataSection.containsKey('constraints') &&
             dataSection.containsKey('shift_time_settings');
    } catch (e) {
      return false;
    }
  }

  // JSON変換ヘルパーメソッド
  static Map<String, dynamic> _staffToJson(Staff staff) {
    return {
      'id': staff.id,
      'name': staff.name,
      'phoneNumber': staff.phoneNumber,
      'email': staff.email,
      'maxShiftsPerMonth': staff.maxShiftsPerMonth,
      'isActive': staff.isActive,
      'preferredDaysOff': staff.preferredDaysOff,
      'unavailableShiftTypes': staff.unavailableShiftTypes,
    };
  }

  static Staff _staffFromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      maxShiftsPerMonth: json['maxShiftsPerMonth'] as int? ?? 20,
      isActive: json['isActive'] as bool? ?? true,
      preferredDaysOff: List<int>.from(json['preferredDaysOff'] ?? []),
      unavailableShiftTypes: List<String>.from(json['unavailableShiftTypes'] ?? []),
    );
  }

  static Map<String, dynamic> _shiftToJson(Shift shift) {
    return {
      'id': shift.id,
      'date': shift.date.toIso8601String(),
      'staffId': shift.staffId,
      'shiftType': shift.shiftType,
      'startTime': shift.startTime.toIso8601String(),
      'endTime': shift.endTime.toIso8601String(),
    };
  }

  static Shift _shiftFromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      staffId: json['staffId'] as String,
      shiftType: json['shiftType'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
    );
  }

  static Map<String, dynamic> _constraintToJson(ShiftConstraint constraint) {
    return {
      'id': constraint.id,
      'staffId': constraint.staffId,
      'date': constraint.date.toIso8601String(),
      'isAvailable': constraint.isAvailable,
      'reason': constraint.reason,
    };
  }

  static ShiftConstraint _constraintFromJson(Map<String, dynamic> json) {
    return ShiftConstraint(
      id: json['id'] as String,
      staffId: json['staffId'] as String,
      date: DateTime.parse(json['date'] as String),
      isAvailable: json['isAvailable'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }

  static Map<String, dynamic> _shiftTimeSettingToJson(ShiftTimeSetting setting) {
    return {
      'shiftType': setting.shiftType.index,
      'customName': setting.customName,
      'startTime': setting.startTime,
      'endTime': setting.endTime,
      'isActive': setting.isActive,
    };
  }

  static ShiftTimeSetting _shiftTimeSettingFromJson(Map<String, dynamic> json) {
    return ShiftTimeSetting(
      shiftType: ShiftType.values[json['shiftType'] as int],
      customName: json['customName'] as String?,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}