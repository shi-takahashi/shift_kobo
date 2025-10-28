import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../models/staff.dart';
import '../models/shift.dart';
import '../models/shift_constraint.dart';
import '../models/shift_time_setting.dart';

class BackupService {
  static const String backupFilePrefix = 'shift_kobo_backup_';
  static const String backupFileExtension = '.json';

  /// 全データのバックアップを作成（Firestoreから）
  static Future<Map<String, dynamic>> createBackupData(String teamId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Firestoreからデータを取得

      // スタッフデータ
      final staffSnapshot = await firestore
          .collection('teams')
          .doc(teamId)
          .collection('staff')
          .get();

      // シフトデータ
      final shiftsSnapshot = await firestore
          .collection('teams')
          .doc(teamId)
          .collection('shifts')
          .get();

      // 制約データ
      final constraintsSnapshot = await firestore
          .collection('teams')
          .doc(teamId)
          .collection('constraints')
          .get();

      // シフト時間設定
      final shiftTimeSnapshot = await firestore
          .collection('teams')
          .doc(teamId)
          .collection('shift_time_settings')
          .get();
      print('シフト時間設定: ${shiftTimeSnapshot.docs.length}件');

      // 月間必要人数設定
      final monthlyReqDoc = await firestore
          .collection('teams')
          .doc(teamId)
          .collection('settings')
          .doc('monthly_requirements')
          .get();

      final shiftRequirements = <String, int>{};
      if (monthlyReqDoc.exists) {
        final data = monthlyReqDoc.data();
        if (data != null) {
          data.forEach((key, value) {
            if (key != 'updatedAt' && value is int) {
              shiftRequirements[key] = value;
            }
          });
        }
      }

      // バックアップデータの構築
      final backupData = {
        'version': '2.0.0', // Firestore版
        'created_at': DateTime.now().toIso8601String(),
        'app_name': 'シフト工房',
        'teamId': teamId, // チームIDを含める
        'data': {
          'staff': staffSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'phoneNumber': data['phoneNumber'],
              'email': data['email'],
              'maxShiftsPerMonth': data['maxShiftsPerMonth'] ?? 20,
              'isActive': data['isActive'] ?? true,
              'preferredDaysOff': List<int>.from(data['preferredDaysOff'] ?? []),
              'unavailableShiftTypes': List<String>.from(data['unavailableShiftTypes'] ?? []),
              'specificDaysOff': List<String>.from(data['specificDaysOff'] ?? []),
            };
          }).toList(),
          'shifts': shiftsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'date': (data['date'] as Timestamp).toDate().toIso8601String(),
              'staffId': data['staffId'] ?? '',
              'shiftType': data['shiftType'] ?? '',
              'startTime': (data['startTime'] as Timestamp).toDate().toIso8601String(),
              'endTime': (data['endTime'] as Timestamp).toDate().toIso8601String(),
              'note': data['note'],
            };
          }).toList(),
          'constraints': constraintsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'staffId': data['staffId'] ?? '',
              'date': (data['date'] as Timestamp).toDate().toIso8601String(),
              'isAvailable': data['isAvailable'] ?? false,
              'reason': data['reason'],
            };
          }).toList(),
          'shift_time_settings': shiftTimeSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,  // IDを保存
              'shiftType': data['shiftType'] as int,
              'customName': data['customName'],
              'startTime': data['startTime'] as String,
              'endTime': data['endTime'] as String,
              'isActive': data['isActive'] ?? true,
            };
          }).toList(),
          'shift_requirements': shiftRequirements,
        },
        'statistics': {
          'staff_count': staffSnapshot.docs.length,
          'shifts_count': shiftsSnapshot.docs.length,
          'constraints_count': constraintsSnapshot.docs.length,
          'shift_time_settings_count': shiftTimeSnapshot.docs.length,
        },
      };

      return backupData;
    } catch (e, stackTrace) {
      throw Exception('バックアップデータの作成に失敗しました: $e');
    }
  }

  /// バックアップファイルを作成して保存
  static Future<String?> saveBackupToFile(String teamId) async {
    try {
      final backupData = await createBackupData(teamId);
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      // ユーザーが保存先を選択
      final timestamp = DateTime.now().toIso8601String().split('T')[0].replaceAll('-', '');
      final fileName = '$backupFilePrefix$timestamp$backupFileExtension';

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

      return null;
    } catch (e) {
      throw Exception('バックアップファイルの保存に失敗しました: $e');
    }
  }

  /// バックアップファイルを共有
  static Future<String?> shareBackupFile(String teamId) async {
    try {
      final filePath = await saveBackupToFile(teamId);

      if (filePath != null) {
        return filePath;
      } else {
        print('保存がキャンセルされました');
        return null;
      }
    } catch (e, stackTrace) {
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

  /// バックアップファイルから復元（Firestoreへ）
  static Future<void> restoreFromFile(String filePath, String teamId, {bool overwrite = false}) async {
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
      final firestore = FirebaseFirestore.instance;

      // シフト時間設定を先に復元（空の状態を作らないため）
      // この処理を削除より前に行うことで、Providerの自動作成を防ぐ
      if (data['shift_time_settings'] != null) {
        final settingsList = data['shift_time_settings'] as List;
        final batch = firestore.batch();
        final backupIds = <String>{};

        for (var settingJson in settingsList) {
          final json = settingJson as Map<String, dynamic>;
          final docId = json['id'] as String?;

          if (docId != null && docId.isNotEmpty) {
            backupIds.add(docId);
          }

          // IDがある場合は指定、ない場合は自動生成
          final docRef = (docId != null && docId.isNotEmpty)
              ? firestore
                  .collection('teams')
                  .doc(teamId)
                  .collection('shift_time_settings')
                  .doc(docId)
              : firestore
                  .collection('teams')
                  .doc(teamId)
                  .collection('shift_time_settings')
                  .doc();

          batch.set(docRef, {
            'shiftType': json['shiftType'] as int,
            'customName': json['customName'],
            'startTime': json['startTime'] as String,
            'endTime': json['endTime'] as String,
            'isActive': json['isActive'] ?? true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();

        // オーバーライトモードの場合、バックアップにない既存ドキュメントを削除
        if (overwrite) {
          final existingDocs = await firestore
              .collection('teams')
              .doc(teamId)
              .collection('shift_time_settings')
              .get();

          final idsToDelete = existingDocs.docs
              .where((doc) => !backupIds.contains(doc.id))
              .toList();

          if (idsToDelete.isNotEmpty) {
            final deleteBatch = firestore.batch();
            for (var doc in idsToDelete) {
              deleteBatch.delete(doc.reference);
            }
            await deleteBatch.commit();
            print('余分なシフト時間設定を削除: ${idsToDelete.length}件');
          }
        }
      }

      if (overwrite) {
        // シフト時間設定以外の既存データをバッチ削除
        await _clearFirestoreDataExceptShiftTime(firestore, teamId);
      }


      // スタッフデータの復元
      if (data['staff'] != null) {
        final staffList = data['staff'] as List;
        final batch = firestore.batch();

        for (var staffJson in staffList) {
          final json = staffJson as Map<String, dynamic>;
          final docRef = firestore
              .collection('teams')
              .doc(teamId)
              .collection('staff')
              .doc(json['id'] as String);

          batch.set(docRef, {
            'name': json['name'] ?? '',
            'phoneNumber': json['phoneNumber'],
            'email': json['email'],
            'maxShiftsPerMonth': json['maxShiftsPerMonth'] ?? 20,
            'isActive': json['isActive'] ?? true,
            'preferredDaysOff': List<int>.from(json['preferredDaysOff'] ?? []),
            'unavailableShiftTypes': List<String>.from(json['unavailableShiftTypes'] ?? []),
            'specificDaysOff': List<String>.from(json['specificDaysOff'] ?? []),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      // シフトデータの復元
      if (data['shifts'] != null) {
        final shiftsList = data['shifts'] as List;

        // 500件ずつバッチ処理
        for (var i = 0; i < shiftsList.length; i += 500) {
          final batch = firestore.batch();
          final end = (i + 500 < shiftsList.length) ? i + 500 : shiftsList.length;

          for (var j = i; j < end; j++) {
            final json = shiftsList[j] as Map<String, dynamic>;
            final docRef = firestore
                .collection('teams')
                .doc(teamId)
                .collection('shifts')
                .doc(json['id'] as String);

            batch.set(docRef, {
              'date': Timestamp.fromDate(DateTime.parse(json['date'] as String)),
              'staffId': json['staffId'] ?? '',
              'shiftType': json['shiftType'] ?? '',
              'startTime': Timestamp.fromDate(DateTime.parse(json['startTime'] as String)),
              'endTime': Timestamp.fromDate(DateTime.parse(json['endTime'] as String)),
              'note': json['note'],
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          await batch.commit();
        }
      }

      // 制約データの復元
      if (data['constraints'] != null) {
        final constraintsList = data['constraints'] as List;
        final batch = firestore.batch();

        for (var constraintJson in constraintsList) {
          final json = constraintJson as Map<String, dynamic>;
          final docRef = firestore
              .collection('teams')
              .doc(teamId)
              .collection('constraints')
              .doc(json['id'] as String);

          batch.set(docRef, {
            'staffId': json['staffId'] ?? '',
            'date': Timestamp.fromDate(DateTime.parse(json['date'] as String)),
            'isAvailable': json['isAvailable'] ?? false,
            'reason': json['reason'],
          });
        }

        await batch.commit();
      }

      // シフト時間設定は既に復元済み（上部で処理）

      // 月間必要人数設定の復元
      if (data['shift_requirements'] != null) {
        final requirements = data['shift_requirements'] as Map<String, dynamic>;
        final requirementsData = <String, dynamic>{};

        requirements.forEach((key, value) {
          requirementsData[key] = value as int;
        });

        requirementsData['updatedAt'] = FieldValue.serverTimestamp();

        await firestore
            .collection('teams')
            .doc(teamId)
            .collection('settings')
            .doc('monthly_requirements')
            .set(requirementsData);

      }


    } catch (e, stackTrace) {
      throw Exception('データの復元に失敗しました: $e');
    }
  }

  /// Firestoreの既存データをクリア（シフト時間設定以外）
  static Future<void> _clearFirestoreDataExceptShiftTime(FirebaseFirestore firestore, String teamId) async {
    // スタッフ削除
    final staffDocs = await firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .get();

    if (staffDocs.docs.isNotEmpty) {
      final batch = firestore.batch();
      for (var doc in staffDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // シフト削除（バッチ処理）
    final shiftDocs = await firestore
        .collection('teams')
        .doc(teamId)
        .collection('shifts')
        .get();

    if (shiftDocs.docs.isNotEmpty) {
      for (var i = 0; i < shiftDocs.docs.length; i += 500) {
        final batch = firestore.batch();
        final end = (i + 500 < shiftDocs.docs.length) ? i + 500 : shiftDocs.docs.length;

        for (var j = i; j < end; j++) {
          batch.delete(shiftDocs.docs[j].reference);
        }

        await batch.commit();
      }
    }

    // 制約削除
    final constraintDocs = await firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraints')
        .get();

    if (constraintDocs.docs.isNotEmpty) {
      final batch = firestore.batch();
      for (var doc in constraintDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // シフト時間設定は削除しない（空の状態を避けるため）

  }

  /// Firestoreの既存データをクリア
  static Future<void> _clearFirestoreData(FirebaseFirestore firestore, String teamId) async {
    // スタッフ削除
    final staffDocs = await firestore
        .collection('teams')
        .doc(teamId)
        .collection('staff')
        .get();

    if (staffDocs.docs.isNotEmpty) {
      final batch = firestore.batch();
      for (var doc in staffDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // シフト削除（バッチ処理）
    final shiftDocs = await firestore
        .collection('teams')
        .doc(teamId)
        .collection('shifts')
        .get();

    if (shiftDocs.docs.isNotEmpty) {
      for (var i = 0; i < shiftDocs.docs.length; i += 500) {
        final batch = firestore.batch();
        final end = (i + 500 < shiftDocs.docs.length) ? i + 500 : shiftDocs.docs.length;

        for (var j = i; j < end; j++) {
          batch.delete(shiftDocs.docs[j].reference);
        }

        await batch.commit();
      }
    }

    // 制約削除
    final constraintDocs = await firestore
        .collection('teams')
        .doc(teamId)
        .collection('constraints')
        .get();

    if (constraintDocs.docs.isNotEmpty) {
      final batch = firestore.batch();
      for (var doc in constraintDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // シフト時間設定削除
    final shiftTimeDocs = await firestore
        .collection('teams')
        .doc(teamId)
        .collection('shift_time_settings')
        .get();

    if (shiftTimeDocs.docs.isNotEmpty) {
      final batch = firestore.batch();
      for (var doc in shiftTimeDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
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
}
