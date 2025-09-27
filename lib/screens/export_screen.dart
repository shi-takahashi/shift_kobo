import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import '../providers/shift_provider.dart';
import '../providers/staff_provider.dart';
import '../models/shift.dart';
import '../providers/shift_time_provider.dart';
import '../models/shift_time_setting.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  DateTime _selectedMonth = DateTime.now();
  bool _isProcessing = false;
  
  @override
  Widget build(BuildContext context) {
    final shiftProvider = Provider.of<ShiftProvider>(context);
    final staffProvider = Provider.of<StaffProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('保存・共有'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '対象月: ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('yyyy年MM月').format(_selectedMonth)),
                  onPressed: _selectMonth,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Stack(
                children: [
                  // 画面表示用（スクロール可能）
                  _buildCalendarPreview(shiftProvider, staffProvider),
                  // スクリーンショット用（非表示、全体表示）
                  Positioned(
                    left: -2000, // 画面外に配置
                    child: Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        color: Colors.white,
                        child: _buildFullCalendarForCapture(
                          shiftProvider,
                          staffProvider,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _captureScreenshot,
                          icon: const Icon(Icons.image),
                          label: const Text('スクリーンショット保存'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exportToExcel,
                          icon: const Icon(Icons.table_chart),
                          label: const Text('Excel保存'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _shareShift,
                      icon: const Icon(Icons.share),
                      label: const Text('共有'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMonth() async {
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('月を選択'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 年選択
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setDialogState(() {
                              selectedYear--;
                            });
                          },
                        ),
                        Text(
                          '$selectedYear年',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setDialogState(() {
                              selectedYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 月選択グリッド
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final month = index + 1;
                        final isSelected = selectedYear == _selectedMonth.year && 
                                         month == _selectedMonth.month;
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMonth = DateTime(selectedYear, month, 1);
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 85,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected 
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$month月',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _captureScreenshot() async {
    setState(() => _isProcessing = true);
    
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image == null) {
        throw Exception('スクリーンショットの取得に失敗しました');
      }

      // ファイル名を生成
      final fileName = 'shift_${DateFormat('yyyyMM').format(_selectedMonth)}.png';
      
      // ユーザーが保存先を選択
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'スクリーンショットの保存先を選択',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['png'],
        bytes: image,
      );
      
      if (outputFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('スクリーンショットを保存しました\n$fileName'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      // キャンセルされた場合は何もしない
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }



  String _getWeekdayString(int weekday) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return weekdays[weekday - 1];
  }

  Future<void> _exportToExcel() async {
    setState(() => _isProcessing = true);
    
    try {
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Sheet1'];
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      final staffProvider = Provider.of<StaffProvider>(context, listen: false);
      final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
      final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
      final shifts = shiftProvider.getMonthlyShiftMap(
        _selectedMonth.year,
        _selectedMonth.month,
      );
      
      // ヘッダー行
      sheet.appendRow([
        excel.TextCellValue('シフト表 - ${DateFormat('yyyy年MM月').format(_selectedMonth)}')
      ]);
      sheet.appendRow([]); // 空行
      
      final headers = <excel.CellValue?>[
        excel.TextCellValue('日付')
      ];
      for (final setting in activeSettings) {
        headers.add(excel.TextCellValue(setting.displayName));
      }
      sheet.appendRow(headers);
      
      // データ行
      final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final dayShifts = shifts[date] ?? [];
        
        final row = <excel.CellValue?>[
          excel.TextCellValue('${date.day}日 (${_getWeekdayString(date.weekday)})')
        ];
        
        for (final setting in activeSettings) {
          final typeShifts = dayShifts.where((s) => s.shiftType == setting.displayName).toList();
          final staffInfo = typeShifts
              .map((s) {
                final staff = staffProvider.getStaffById(s.staffId);
                final staffName = staff?.name ?? 'Unknown';
                
                // 標準時間と異なるかチェック
                final actualStartTime = DateFormat('HH:mm').format(s.startTime);
                final actualEndTime = DateFormat('HH:mm').format(s.endTime);
                final isDifferentTime = actualStartTime != setting.startTime || actualEndTime != setting.endTime;
                
                if (isDifferentTime) {
                  return '$staffName ($actualStartTime-$actualEndTime)';
                } else {
                  return staffName;
                }
              })
              .join(', ');
          row.add(excel.TextCellValue(staffInfo));
        }
        
        sheet.appendRow(row);
      }

      final excelBytes = excelFile.save();
      if (excelBytes != null) {
        // ファイル名を生成
        final fileName = 'shift_${DateFormat('yyyyMM').format(_selectedMonth)}.xlsx';
        
        // ユーザーが保存先を選択
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Excelファイルの保存先を選択',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(excelBytes),
        );
        
        if (outputFile != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Excelファイルを保存しました\n$fileName'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        // キャンセルされた場合は何もしない
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareShift() async {
    // 共有形式選択ダイアログを表示
    final selectedFormat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('共有形式を選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('PNG画像'),
                subtitle: const Text('LINEやメールでの共有・確認用'),
                onTap: () => Navigator.pop(context, 'png'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Excelファイル'),
                subtitle: const Text('Googleドライブに保存→編集・レイアウト調整→印刷'),
                onTap: () => Navigator.pop(context, 'excel'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
          ],
        );
      },
    );

    if (selectedFormat == null) return; // キャンセルされた場合

    setState(() => _isProcessing = true);
    
    try {
      if (selectedFormat == 'png') {
        await _shareAsPng();
      } else if (selectedFormat == 'excel') {
        await _shareAsExcel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareAsPng() async {
    // スクリーンショットを取得
    final Uint8List? image = await _screenshotController.capture();
    if (image == null) {
      throw Exception('スクリーンショットの取得に失敗しました');
    }

    // 一時ファイルに保存
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/shift_${DateFormat('yyyyMM').format(_selectedMonth)}.png');
    await file.writeAsBytes(image);

    // 共有
    final result = await Share.shareXFiles(
      [XFile(file.path)],
      text: '${DateFormat('yyyy年MM月').format(_selectedMonth)}のシフト表（PNG画像）',
    );

    // 実際に共有された場合のみ成功メッセージ
    if (mounted && result.status == ShareResultStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PNG画像を共有しました'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _shareAsExcel() async {
    // Excelファイルを生成
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Sheet1'];
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
    final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
    final shifts = shiftProvider.getMonthlyShiftMap(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    
    // ヘッダー行
    sheet.appendRow([
      excel.TextCellValue('シフト表 - ${DateFormat('yyyy年MM月').format(_selectedMonth)}')
    ]);
    sheet.appendRow([]); // 空行
    
    final headers = <excel.CellValue?>[
      excel.TextCellValue('日付')
    ];
    for (final setting in activeSettings) {
      headers.add(excel.TextCellValue(setting.displayName));
    }
    sheet.appendRow(headers);
    
    // データ行
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final dayShifts = shifts[date] ?? [];
      
      final row = <excel.CellValue?>[
        excel.TextCellValue('${date.day}日 (${_getWeekdayString(date.weekday)})')
      ];
      
      for (final setting in activeSettings) {
        final typeShifts = dayShifts.where((s) => s.shiftType == setting.displayName).toList();
        final staffInfo = typeShifts
            .map((s) {
              final staff = staffProvider.getStaffById(s.staffId);
              final staffName = staff?.name ?? 'Unknown';
              
              // 標準時間と異なるかチェック
              final actualStartTime = DateFormat('HH:mm').format(s.startTime);
              final actualEndTime = DateFormat('HH:mm').format(s.endTime);
              final isDifferentTime = actualStartTime != setting.startTime || actualEndTime != setting.endTime;
              
              if (isDifferentTime) {
                return '$staffName ($actualStartTime-$actualEndTime)';
              } else {
                return staffName;
              }
            })
            .join(', ');
        row.add(excel.TextCellValue(staffInfo));
      }
      
      sheet.appendRow(row);
    }

    final excelBytes = excelFile.save();
    if (excelBytes != null) {
      // 一時ファイルに保存
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/shift_${DateFormat('yyyyMM').format(_selectedMonth)}.xlsx');
      await file.writeAsBytes(excelBytes);

      // 共有
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: '${DateFormat('yyyy年MM月').format(_selectedMonth)}のシフト表（Excelファイル）',
      );

      // 実際に共有された場合のみ成功メッセージ
      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excelファイルを共有しました'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildCalendarPreview(ShiftProvider shiftProvider, StaffProvider staffProvider) {
    final shifts = shiftProvider.getMonthlyShiftMap(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: _buildCalendarTable(shifts, staffProvider),
      ),
    );
  }

  Widget _buildCalendarTable(Map<DateTime, List<Shift>> shifts, StaffProvider staffProvider) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    
    return DataTable(
      columnSpacing: 20,
      headingRowHeight: 40,
      dataRowMinHeight: 60,
      dataRowMaxHeight: 100,
      columns: _buildDataColumns(),
      rows: _buildDataRows(daysInMonth, shifts, staffProvider),
    );
  }

  List<DataColumn> _buildDataColumns() {
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
    final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
    
    final columns = <DataColumn>[
      const DataColumn(label: Text('日付', style: TextStyle(fontWeight: FontWeight.bold))),
    ];
    
    for (final setting in activeSettings) {
      final color = setting.shiftType.color;
      columns.add(
        DataColumn(
          label: Container(
            color: color.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  setting.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${setting.startTime}-${setting.endTime}',
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return columns;
  }

  List<DataRow> _buildDataRows(int daysInMonth, Map<DateTime, List<Shift>> shifts, StaffProvider staffProvider) {
    final rows = <DataRow>[];
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final dayShifts = shifts[date] ?? [];
      final weekday = _getWeekdayString(date.weekday);
      final isWeekend = date.weekday == 6 || date.weekday == 7;
      
      final cells = <DataCell>[
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isWeekend ? Colors.red : null,
                  ),
                ),
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 12,
                    color: isWeekend ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
      
      final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
      final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
      
      for (final setting in activeSettings) {
        final typeShifts = dayShifts.where((s) => s.shiftType == setting.displayName).toList();
        cells.add(
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: typeShifts.map((shift) {
                  final staff = staffProvider.getStaffById(shift.staffId);
                  
                  // 標準時間と異なるかチェック
                  final actualStartTime = DateFormat('HH:mm').format(shift.startTime);
                  final actualEndTime = DateFormat('HH:mm').format(shift.endTime);
                  final isDifferentTime = actualStartTime != setting.startTime || actualEndTime != setting.endTime;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: isDifferentTime
                        ? Row(
                            children: [
                              Text(
                                staff?.name ?? 'Unknown',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '($actualStartTime-$actualEndTime)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            staff?.name ?? 'Unknown',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      }
      
      rows.add(DataRow(cells: cells));
    }
    
    return rows;
  }

  Widget _buildFullCalendarForCapture(ShiftProvider shiftProvider, StaffProvider staffProvider) {
    final shifts = shiftProvider.getMonthlyShiftMap(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    
    // スクリーンショット用に全体が表示されるように作成
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // タイトル
          Center(
            child: Text(
              'シフト表 - ${DateFormat('yyyy年MM月').format(_selectedMonth)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // カレンダーテーブル（固定幅で全体表示）
          Container(
            constraints: const BoxConstraints(minWidth: 800, maxWidth: 1200),
            child: _buildCalendarTable(shifts, staffProvider),
          ),
        ],
      ),
    );
  }
}