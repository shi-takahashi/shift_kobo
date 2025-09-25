import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shift.dart';
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

  void _saveShift() {
    if (_formKey.currentState!.validate()) {
      final shiftProvider = context.read<ShiftProvider>();
      
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
}