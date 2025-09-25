import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_type.dart' as old_shift_type;
import '../models/shift_time_setting.dart';
import '../providers/shift_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/shift_time_provider.dart';
import '../services/shift_assignment_service.dart';
import '../models/shift.dart';

class AutoAssignmentDialog extends StatefulWidget {
  final DateTime selectedMonth;

  const AutoAssignmentDialog({
    super.key,
    required this.selectedMonth,
  });

  @override
  State<AutoAssignmentDialog> createState() => _AutoAssignmentDialogState();
}

class _AutoAssignmentDialogState extends State<AutoAssignmentDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  final Map<String, TextEditingController> _requirementControllers = {};
  bool _isProcessing = false;
  String? _errorMessage;
  List<Shift>? _previewShifts;
  
  // 旧ShiftType（文字列）から新ShiftType（enum）へのマッピング
  static Map<String, ShiftType> get _shiftTypeMapping => {
    '早番': ShiftType.shift1,
    '日勤': ShiftType.shift2,
    '遅番': ShiftType.shift3,
    '夜勤': ShiftType.shift4,
    '終日': ShiftType.shift5,
  };
  
  String _getStringFromShiftType(ShiftType shiftType) {
    return _shiftTypeMapping.entries
        .firstWhere((entry) => entry.value == shiftType, orElse: () => const MapEntry('日勤', ShiftType.shift2))
        .key;
  }

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
    _endDate = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
  }
  
  void _initializeControllers(List<ShiftTimeSetting> activeSettings) {
    // 既存のコントローラーをクリア
    for (var controller in _requirementControllers.values) {
      controller.dispose();
    }
    _requirementControllers.clear();
    
    // アクティブな設定に対してコントローラーを作成
    for (var setting in activeSettings) {
      final shiftTypeString = _getStringFromShiftType(setting.shiftType);
      _requirementControllers[shiftTypeString] = TextEditingController(text: '0');
    }
    
    _loadSavedRequirements();
  }

  Future<void> _loadSavedRequirements() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      for (String shiftType in _requirementControllers.keys) {
        int defaultValue = 0;
        // 日勤のみデフォルト値を1にする
        if (shiftType == '日勤') {
          defaultValue = 1;
        }
        
        final savedValue = prefs.getInt('shift_requirement_$shiftType') ?? defaultValue;
        _requirementControllers[shiftType]!.text = savedValue.toString();
      }
    });
  }

  Future<void> _saveRequirements() async {
    final prefs = await SharedPreferences.getInstance();
    
    for (var entry in _requirementControllers.entries) {
      final value = int.tryParse(entry.value.text) ?? 0;
      await prefs.setInt('shift_requirement_${entry.key}', value);
    }
  }

  @override
  void dispose() {
    for (var controller in _requirementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShiftTimeProvider>(
      builder: (context, shiftTimeProvider, child) {
        final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
        
        // 初回または活性設定変更時にコントローラーを初期化
        if (_requirementControllers.isEmpty || _requirementControllers.keys.length != activeSettings.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeControllers(activeSettings);
          });
        }
        
        return AlertDialog(
          title: const Text('自動シフト割り当て'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.selectedMonth.year}年${widget.selectedMonth.month}月のシフトを自動作成します',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '各シフトタイプの必要人数：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (activeSettings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'アクティブなシフトタイプがありません。\n設定画面でシフトタイプを有効にしてください。',
                        style: TextStyle(color: Colors.orange.shade700),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...activeSettings.map((setting) => _buildRequirementField(setting)),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                  if (_previewShifts != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_previewShifts!.length}件のシフトが作成されます',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                      if (_previewShifts!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '期間: ${_startDate.month}/${_startDate.day} 〜 ${_endDate.month}/${_endDate.day}',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                        ),
                        const SizedBox(height: 8),
                        _buildShiftSummary(),
                      ],
                    ],
                  ),
                ),
              ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            if (activeSettings.isEmpty)
              const SizedBox()
            else if (_previewShifts == null) ...[
              ElevatedButton(
                onPressed: _isProcessing ? null : _previewAssignment,
                child: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('シフトを生成'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _isProcessing ? null : _applyAssignment,
                child: const Text('確定して保存'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRequirementField(ShiftTimeSetting setting) {
    final shiftTypeString = _getStringFromShiftType(setting.shiftType);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
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
          Expanded(
            flex: 2,
            child: Text(
              setting.displayName,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              setting.timeRange,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _requirementControllers[shiftTypeString],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              readOnly: _previewShifts != null, // プレビュー表示中は読み取り専用
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('人'),
        ],
      ),
    );
  }

  Future<void> _previewAssignment() async {
    // キーボードを閉じる
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _previewShifts = null;
    });

    try {
      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      
      final requirements = <String, int>{};
      for (var entry in _requirementControllers.entries) {
        final value = int.tryParse(entry.value.text) ?? 0;
        if (value > 0) {
          requirements[entry.key] = value;
        }
      }

      if (requirements.isEmpty) {
        throw Exception('少なくとも1つのシフトタイプに人数を設定してください');
      }

      final service = ShiftAssignmentService(
        staffProvider: staffProvider,
        shiftProvider: shiftProvider,
      );

      final existingShifts = shiftProvider.getShiftsForMonth(widget.selectedMonth.year, widget.selectedMonth.month);
      if (existingShifts.isNotEmpty) {
        final confirmed = await _showConfirmationDialog(
          '既存のシフトがあります',
          'このまま続けると、既存のシフトは削除されます。続けますか？',
        );
        if (!confirmed) {
          setState(() {
            _isProcessing = false;
          });
          // キーボードを再度閉じる
          FocusScope.of(context).unfocus();
          return;
        }
      }

      final shifts = await service.autoAssignShifts(
        _startDate,
        _endDate,
        requirements,
      );

      // 設定を保存
      await _saveRequirements();

      // キーボードを再度閉じる（プレビュー表示前）
      FocusScope.of(context).unfocus();

      setState(() {
        _previewShifts = shifts;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<void> _applyAssignment() async {
    if (_previewShifts == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      
      final existingShifts = shiftProvider.getShiftsForMonth(widget.selectedMonth.year, widget.selectedMonth.month);
      for (var shift in existingShifts) {
        await shiftProvider.deleteShift(shift.id);
      }

      print('保存開始: ${_previewShifts!.length}件のシフト');
      for (var shift in _previewShifts!) {
        print('保存中: ${shift.date.toString().split(' ')[0]} ${shift.shiftType} - スタッフID: ${shift.staffId}');
        await shiftProvider.addShift(shift);
      }
      print('保存完了');

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('続ける'),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildShiftSummary() {
    if (_previewShifts == null) return const SizedBox();
    
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final Map<String, int> staffShiftCounts = {};
    final Map<String, int> staffMaxShifts = {};
    
    // シフト数を集計
    for (var shift in _previewShifts!) {
      staffShiftCounts[shift.staffId] = (staffShiftCounts[shift.staffId] ?? 0) + 1;
    }
    
    // スタッフの最大シフト数を取得
    for (var staff in staffProvider.staff) {
      staffMaxShifts[staff.id] = staff.maxShiftsPerMonth;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'スタッフ別シフト数:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        ...staffProvider.staff.map((staff) {
          final count = staffShiftCounts[staff.id] ?? 0;
          final max = staff.maxShiftsPerMonth;
          final percentage = max > 0 ? (count / max * 100).round() : 0;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    staff.name,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$count/$max回',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: count == 0 ? Colors.red : null,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($percentage%)',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}