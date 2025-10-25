import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/shift.dart';
import '../models/staff.dart';
import '../models/shift_type.dart' as old_shift_type;
import '../models/shift_time_setting.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/shift_time_provider.dart';

class ShiftEditDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Shift? existingShift;

  const ShiftEditDialog({
    super.key,
    required this.selectedDate,
    this.existingShift,
  });

  @override
  State<ShiftEditDialog> createState() => _ShiftEditDialogState();
}

class _ShiftEditDialogState extends State<ShiftEditDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedStaffId;
  String _selectedShiftType = old_shift_type.ShiftType.day;
  ShiftTimeSetting? _selectedShiftTimeSetting;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 0, minute: 0);
  String _note = '';
  late DateTime _selectedDate;

  // 旧ShiftType（文字列）から新ShiftType（enum）へのマッピング
  static Map<String, ShiftType> get _shiftTypeMapping => {
    '早番': ShiftType.shift1,
    '日勤': ShiftType.shift2,
    '遅番': ShiftType.shift3,
    '夜勤': ShiftType.shift4,
    '終日': ShiftType.shift5,
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    
    // 既存シフト編集の場合は先に初期化
    if (widget.existingShift != null) {
      _initializeWithExistingShift();
    }
  }

  String _getStringFromShiftType(ShiftType shiftType) {
    return _shiftTypeMapping.entries
        .firstWhere((entry) => entry.value == shiftType, orElse: () => MapEntry('日勤', ShiftType.shift2))
        .key;
  }

  void _updateTimeFromSetting(ShiftTimeSetting setting) {
    final startParts = setting.startTime.split(':');
    final endParts = setting.endTime.split(':');
    _startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
    _endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
  }

  void _initializeWithExistingShift() {
    final shift = widget.existingShift!;
    _selectedStaffId = shift.staffId;
    _selectedShiftType = shift.shiftType;
    _startTime = TimeOfDay.fromDateTime(shift.startTime);
    _endTime = TimeOfDay.fromDateTime(shift.endTime);
    _note = shift.note ?? '';
    _selectedDate = shift.date;
    
    // ShiftTimeSettingの初期化はConsumer内で行うため、ここでは何もしない
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // スクロール可能なコンテンツ部分
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  thickness: 6.0,
                  radius: const Radius.circular(3.0),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingShift != null ? 'シフト編集' : 'シフト追加',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        
                        // 日付選択
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '日付',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Consumer<StaffProvider>(
                          builder: (context, staffProvider, child) {
                            // アクティブなスタッフのみ
                            final activeStaff = staffProvider.activeStaffList;

                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'スタッフ',
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedStaffId,
                              items: activeStaff.map((staff) {
                                return DropdownMenuItem(
                                  value: staff.id,
                                  child: Text(staff.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedStaffId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'スタッフを選択してください';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Consumer<ShiftTimeProvider>(
                          builder: (context, shiftTimeProvider, child) {
                            final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
                            
                            // 初回読み込み時にactiveSettingsが空の場合は、初期化完了を待つ
                            if (activeSettings.isEmpty) {
                              return DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'シフトタイプ',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [],
                                onChanged: null,
                              );
                            }
                            
                            // 既存シフトの場合、カスタム名で直接マッチング
                            if (widget.existingShift != null && _selectedShiftTimeSetting == null) {
                              final shift = widget.existingShift!;
                              
                              // まずカスタム名で直接検索
                              ShiftTimeSetting? foundSetting;
                              try {
                                foundSetting = activeSettings
                                    .where((s) => s.displayName == shift.shiftType)
                                    .first;
                              } catch (e) {
                                // カスタム名で見つからない場合は、従来のマッピングを試す
                                final mappedShiftType = _shiftTypeMapping[shift.shiftType];
                                if (mappedShiftType != null) {
                                  try {
                                    foundSetting = activeSettings
                                        .where((s) => s.shiftType == mappedShiftType)
                                        .first;
                                  } catch (e) {
                                    foundSetting = null;
                                  }
                                }
                              }
                              
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setState(() {
                                  if (foundSetting != null) {
                                    _selectedShiftTimeSetting = foundSetting;
                                    // 既存シフト編集時は実際の保存時間を維持（設定時間で上書きしない）
                                    _selectedShiftType = foundSetting.displayName;
                                  } else {
                                    // 見つからない場合は最初の設定を使用
                                    _selectedShiftTimeSetting = activeSettings.first;
                                    _selectedShiftType = activeSettings.first.displayName;
                                  }
                                });
                              });
                            }
                            
                            // 新規シフト作成時は自動選択しない（ユーザーに選択させる）
                            
                            return DropdownButtonFormField<ShiftTimeSetting>(
                              decoration: const InputDecoration(
                                labelText: 'シフトタイプ',
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('シフトタイプを選択してください'),
                              value: _selectedShiftTimeSetting,
                              items: activeSettings.map((setting) {
                                return DropdownMenuItem(
                                  value: setting,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 8,
                                        backgroundColor: setting.shiftType.color,
                                        child: Icon(
                                          setting.shiftType.icon,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${setting.displayName} (${setting.timeRange})'),
                                    ],
                                  ),
                                );
                              }).toList(),
                              selectedItemBuilder: (context) {
                                return activeSettings.map((setting) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 8,
                                        backgroundColor: setting.shiftType.color,
                                        child: Icon(
                                          setting.shiftType.icon,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${setting.displayName} (${setting.timeRange})'),
                                    ],
                                  );
                                }).toList();
                              },
                              onChanged: (setting) {
                                if (setting != null) {
                                  setState(() {
                                    _selectedShiftTimeSetting = setting;
                                    _selectedShiftType = setting.displayName;
                                    _updateTimeFromSetting(setting);
                                  });
                                }
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'シフトタイプを選択してください';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(context, true),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '開始時間',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.access_time),
                                  ),
                                  child: Text(_startTime.format(context)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(context, false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '終了時間',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.access_time),
                                  ),
                                  child: Text(_endTime.format(context)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: '備考（任意）',
                            border: OutlineInputBorder(),
                            hintText: '特記事項があれば入力',
                          ),
                          initialValue: _note,
                          maxLines: 3,
                          onChanged: (value) {
                            _note = value;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 固定のアクションボタン
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveShift,
                        child: Text(widget.existingShift != null ? '更新' : '追加'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveShift() async {
    if (_formKey.currentState!.validate()) {
      final shiftProvider = context.read<ShiftProvider>();
      final staffProvider = context.read<StaffProvider>();

      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final staff = staffProvider.staffList.firstWhere((s) => s.id == _selectedStaffId!);

      // 1. 時間重複チェック（絶対NG - 先にチェック）
      final conflictingShift = _checkTimeConflict(
        staffId: _selectedStaffId!,
        startTime: startDateTime,
        endTime: endDateTime,
        excludeShiftId: widget.existingShift?.id,
        shiftProvider: shiftProvider,
      );

      if (conflictingShift != null) {
        _showConflictDialog(conflictingShift, staff.name);
        return;
      }

      // 2. 制約チェック（警告付きで保存可能 - 後でチェック）
      final constraintViolations = _checkConstraintViolations(staff, shiftProvider);

      if (constraintViolations.isNotEmpty) {
        final shouldContinue = await _showConstraintWarningDialog(staff, constraintViolations);
        if (!shouldContinue) {
          return;
        }
      }
      
      if (widget.existingShift != null) {
        // 編集モード
        // ShiftTimeSettingのカスタム名を直接使用
        String shiftTypeForSave = _selectedShiftType;
        if (_selectedShiftTimeSetting != null) {
          shiftTypeForSave = _selectedShiftTimeSetting!.displayName;
        }
        
        final updatedShift = Shift(
          id: widget.existingShift!.id,
          staffId: _selectedStaffId!,
          date: _selectedDate,
          startTime: startDateTime,
          endTime: endDateTime,
          shiftType: shiftTypeForSave,
          note: _note.isNotEmpty ? _note : null,
        );
        
        shiftProvider.updateShift(updatedShift);
      } else {
        // 追加モード
        // ShiftTimeSettingのカスタム名を直接使用
        String shiftTypeForSave = _selectedShiftType;
        if (_selectedShiftTimeSetting != null) {
          shiftTypeForSave = _selectedShiftTimeSetting!.displayName;
        }
        
        final newShift = Shift(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          staffId: _selectedStaffId!,
          date: _selectedDate,
          startTime: startDateTime,
          endTime: endDateTime,
          shiftType: shiftTypeForSave,
          note: _note.isNotEmpty ? _note : null,
        );
        
        shiftProvider.addShift(newShift);
      }
      
      Navigator.pop(context, true);
    }
  }

  /// 時間重複チェック
  Shift? _checkTimeConflict({
    required String staffId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeShiftId,
    required ShiftProvider shiftProvider,
  }) {
    final staffShifts = shiftProvider.getShiftsForStaffAndDate(staffId, startTime);
    
    for (final shift in staffShifts) {
      // 編集中のシフト自身は除外
      if (excludeShiftId != null && shift.id == excludeShiftId) {
        continue;
      }
      
      // 時間重複をチェック
      if (_isTimeOverlapping(
        startTime, endTime,
        shift.startTime, shift.endTime,
      )) {
        return shift;
      }
    }
    return null;
  }

  /// 2つの時間範囲が重複しているかチェック
  bool _isTimeOverlapping(
    DateTime start1, DateTime end1,
    DateTime start2, DateTime end2,
  ) {
    // 日またぎを考慮した比較
    // 開始時刻が終了時刻より後の場合は翌日扱い
    if (end1.isBefore(start1)) {
      end1 = end1.add(const Duration(days: 1));
    }
    if (end2.isBefore(start2)) {
      end2 = end2.add(const Duration(days: 1));
    }
    
    // 重複判定: 一方の終了時刻が他方の開始時刻より後で、
    // かつ一方の開始時刻が他方の終了時刻より前
    return start1.isBefore(end2) && start2.isBefore(end1);
  }

  /// 時間重複を警告するダイアログ
  void _showConflictDialog(Shift conflictingShift, String staffName) {
    final conflictStart = TimeOfDay.fromDateTime(conflictingShift.startTime);
    final conflictEnd = TimeOfDay.fromDateTime(conflictingShift.endTime);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('時間重複エラー'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$staffName さんは、同じ日の以下の時間帯に既にシフトが入っています：'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '既存シフト: ${conflictingShift.shiftType}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '時間: ${conflictStart.format(context)} - ${conflictEnd.format(context)}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('同じ人を同時刻に複数のシフトに配置することはできません。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  /// 制約違反をチェック
  List<String> _checkConstraintViolations(Staff staff, ShiftProvider shiftProvider) {
    final violations = <String>[];

    // シフトタイプ名を取得（カスタム名を使用）
    String shiftTypeForCheck = _selectedShiftType;
    if (_selectedShiftTimeSetting != null) {
      shiftTypeForCheck = _selectedShiftTimeSetting!.displayName;
    }

    // 1. 曜日の休み希望チェック
    final weekday = _selectedDate.weekday; // 1-7 (月-日)
    if (staff.preferredDaysOff.contains(weekday)) {
      final dayNames = ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'];
      violations.add('${dayNames[weekday - 1]}は休み希望になっています');
    }

    // 2. 特定日の休み希望チェック
    final dateString = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toIso8601String();
    if (staff.specificDaysOff.contains(dateString)) {
      final dateStr = DateFormat('yyyy/MM/dd(E)', 'ja').format(_selectedDate);
      violations.add('$dateStrは休み希望日になっています');
    }

    // 3. 勤務不可シフトタイプチェック
    if (staff.unavailableShiftTypes.contains(shiftTypeForCheck)) {
      violations.add('$shiftTypeForCheckは勤務不可になっています');
    }

    // 4. 月間最大シフト数チェック
    if (staff.maxShiftsPerMonth > 0) {
      final targetMonth = DateTime(_selectedDate.year, _selectedDate.month);
      final monthlyShifts = shiftProvider.getShiftsForMonth(targetMonth.year, targetMonth.month)
          .where((shift) => shift.staffId == staff.id);

      // スタッフが変更されたか、月が変更されたか判定
      final isStaffChanged = widget.existingShift != null && widget.existingShift!.staffId != staff.id;
      final isMonthChanged = widget.existingShift != null &&
          (widget.existingShift!.date.year != _selectedDate.year ||
           widget.existingShift!.date.month != _selectedDate.month);

      // 既存シフトの編集の場合（同じスタッフ、同じ月）は、そのシフト自体を除外してカウント
      int currentMonthlyCount = monthlyShifts.where((shift) {
        if (widget.existingShift != null && !isStaffChanged && !isMonthChanged) {
          return shift.id != widget.existingShift!.id;
        }
        return true;
      }).length;

      // 新規追加、スタッフ変更、または月変更の場合は+1、それ以外は現在のカウントのまま
      int futureCount = (widget.existingShift == null || isStaffChanged || isMonthChanged)
          ? currentMonthlyCount + 1
          : currentMonthlyCount;

      debugPrint('🔍 [月間最大シフト数チェック] スタッフ: ${staff.name}, 上限: ${staff.maxShiftsPerMonth}, 現在: $currentMonthlyCount, 追加後: $futureCount, スタッフ変更: $isStaffChanged, 月変更: $isMonthChanged');

      if (futureCount > staff.maxShiftsPerMonth) {
        // 上限を超える場合
        violations.add('月間最大シフト数（${staff.maxShiftsPerMonth}回）を超えます（現在: ${currentMonthlyCount}回）');
      }
    }

    return violations;
  }

  /// 制約違反警告ダイアログ
  Future<bool> _showConstraintWarningDialog(Staff staff, List<String> violations) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('制約に該当しています'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${staff.name}さんは以下の制約があります：',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: violations.map((violation) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            violation,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'それでもこのシフトを保存しますか？',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存する'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}