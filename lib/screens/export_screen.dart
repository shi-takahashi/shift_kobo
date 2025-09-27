import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../models/staff.dart';
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
  void initState() {
    super.initState();
    // 画面を横向きに固定（即座に適用）
    _setLandscapeOrientation();
  }

  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  @override
  void dispose() {
    // 画面向きを確実に縦向きに戻す
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]).then((_) {
      // レイアウト安定化のため少し長めに待つ
      Future.delayed(const Duration(milliseconds: 500), () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    });
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // build時にも横向きを確実に維持
    _setLandscapeOrientation();
    
    final shiftProvider = Provider.of<ShiftProvider>(context);
    final staffProvider = Provider.of<StaffProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('シフト表'),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                DateFormat('yyyy年MM月').format(_selectedMonth),
                style: const TextStyle(fontSize: 14),
              ),
              onPressed: _selectMonth,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 操作ボタン
          if (!_isProcessing)
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: _showSaveDialog,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('保存'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _showShareDialog,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('共有'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          // シフト表表示領域
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
        ],
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
      
      // 日付ヘッダー行
      final headers = <excel.CellValue?>[
        excel.TextCellValue('スタッフ')
      ];
      final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final weekday = _getWeekdayString(date.weekday);
        headers.add(excel.TextCellValue('${day}日($weekday)'));
      }
      sheet.appendRow(headers);
      
      // スタッフ行
      final activeStaff = staffProvider.activeStaffList;
      for (final staff in activeStaff) {
        final row = <excel.CellValue?>[
          excel.TextCellValue(staff.name)
        ];
        
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
          final dayShifts = shifts[date] ?? [];
          final staffShift = dayShifts.where((s) => s.staffId == staff.id).firstOrNull;
          
          String cellValue = '';
          if (staffShift != null) {
            final setting = activeSettings.where((s) => s.displayName == staffShift.shiftType).firstOrNull;
            if (setting != null) {
              final shiftChar = setting.displayName.isNotEmpty ? setting.displayName[0] : '?';
              
              // 標準時間と異なるかチェック
              final actualStartTime = DateFormat('HH:mm').format(staffShift.startTime);
              final actualEndTime = DateFormat('HH:mm').format(staffShift.endTime);
              final isDifferentTime = actualStartTime != setting.startTime || actualEndTime != setting.endTime;
              
              if (isDifferentTime) {
                cellValue = '$shiftChar ($actualStartTime-$actualEndTime)';
              } else {
                cellValue = shiftChar;
              }
            } else {
              cellValue = '?';
            }
          }
          row.add(excel.TextCellValue(cellValue));
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


  Future<void> _shareAsPng() async {
    setState(() => _isProcessing = true);
    
    try {
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

  Future<void> _showSaveDialog() async {
    final selectedFormat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('このスマホに保存'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'このスマホ内に保存します',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, 'png'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.image, color: Colors.blue, size: 24),
                            SizedBox(height: 4),
                            Text('PNG画像', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            SizedBox(height: 2),
                            Text(
                              '画像として保存',
                              style: TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, 'excel'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.table_chart, color: Colors.green, size: 24),
                            SizedBox(height: 4),
                            Text('Excelファイル', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            SizedBox(height: 2),
                            Text(
                              'Excel形式で保存',
                              style: TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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

    if (selectedFormat == null) return;

    setState(() => _isProcessing = true);
    
    try {
      if (selectedFormat == 'png') {
        await _captureScreenshot();
      } else if (selectedFormat == 'excel') {
        await _exportToExcel();
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

  Future<void> _showShareDialog() async {
    final selectedFormat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('他のアプリと共有'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '他のアプリと共有します',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, 'png'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.image, color: Colors.blue, size: 24),
                            SizedBox(height: 4),
                            Text('PNG画像', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            SizedBox(height: 2),
                            Text(
                              'LINE・メール等',
                              style: TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, 'excel'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.table_chart, color: Colors.green, size: 24),
                            SizedBox(height: 4),
                            Text('Excelファイル', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            SizedBox(height: 2),
                            Text(
                              'ドライブ→編集→印刷',
                              style: TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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

    if (selectedFormat == null) return;

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

  Future<void> _shareAsExcel() async {
    setState(() => _isProcessing = true);
    
    try {
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
      
      // 日付ヘッダー行
      final headers = <excel.CellValue?>[
        excel.TextCellValue('スタッフ')
      ];
      final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final weekday = _getWeekdayString(date.weekday);
        headers.add(excel.TextCellValue('${day}日($weekday)'));
      }
      sheet.appendRow(headers);
      
      // スタッフ行
      final activeStaff = staffProvider.activeStaffList;
      for (final staff in activeStaff) {
        final row = <excel.CellValue?>[
          excel.TextCellValue(staff.name)
        ];
        
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
          final dayShifts = shifts[date] ?? [];
          final staffShift = dayShifts.where((s) => s.staffId == staff.id).firstOrNull;
          
          String cellValue = '';
          if (staffShift != null) {
            final setting = activeSettings.where((s) => s.displayName == staffShift.shiftType).firstOrNull;
            if (setting != null) {
              final shiftChar = setting.displayName.isNotEmpty ? setting.displayName[0] : '?';
              
              // 標準時間と異なるかチェック
              final actualStartTime = DateFormat('HH:mm').format(staffShift.startTime);
              final actualEndTime = DateFormat('HH:mm').format(staffShift.endTime);
              final isDifferentTime = actualStartTime != setting.startTime || actualEndTime != setting.endTime;
              
              if (isDifferentTime) {
                cellValue = '$shiftChar ($actualStartTime-$actualEndTime)';
              } else {
                cellValue = shiftChar;
              }
            } else {
              cellValue = '?';
            }
          }
          row.add(excel.TextCellValue(cellValue));
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
    final activeStaff = staffProvider.activeStaffList;
    
    return DataTable(
      columnSpacing: 8,
      headingRowHeight: 40,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 36,
      border: TableBorder.all(
        color: Colors.grey.shade300,
        width: 1,
      ),
      columns: _buildDateColumns(daysInMonth),
      rows: _buildStaffRows(daysInMonth, shifts, activeStaff),
    );
  }

  List<DataColumn> _buildDateColumns(int daysInMonth) {
    final columns = <DataColumn>[
      const DataColumn(
        label: Text('スタッフ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ];
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final weekday = _getWeekdayString(date.weekday);
      final isWeekend = date.weekday == 6 || date.weekday == 7;
      
      columns.add(
        DataColumn(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isWeekend ? Colors.red : Colors.black,
                ),
              ),
              Text(
                weekday,
                style: TextStyle(
                  fontSize: 9,
                  color: isWeekend ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return columns;
  }

  List<DataRow> _buildStaffRows(int daysInMonth, Map<DateTime, List<Shift>> shifts, List<Staff> activeStaff) {
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
    final activeSettings = shiftTimeProvider.settings.where((s) => s.isActive).toList();
    final rows = <DataRow>[];
    
    for (final staff in activeStaff) {
      final cells = <DataCell>[
        DataCell(
          Text(
            staff.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ];
      
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final dayShifts = shifts[date] ?? [];
        final staffShift = dayShifts.where((s) => s.staffId == staff.id).firstOrNull;
        
        Widget cellContent;
        if (staffShift != null) {
          // シフトタイプの設定を検索
          final setting = activeSettings.where((s) => s.displayName == staffShift.shiftType).firstOrNull;
          if (setting != null) {
            final shiftChar = setting.displayName.isNotEmpty ? setting.displayName[0] : '?';
            final color = setting.shiftType.color;
            
            // 標準時間と異なるかチェック
            final actualStartTime = DateFormat('HH:mm').format(staffShift.startTime);
            final actualEndTime = DateFormat('HH:mm').format(staffShift.endTime);
            final isDifferentTime = actualStartTime != setting.startTime || actualEndTime != setting.endTime;
            
            cellContent = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shiftChar,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (isDifferentTime) ...[
                  const SizedBox(width: 2),
                  Text(
                    '!',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            );
          } else {
            cellContent = const Text('?', style: TextStyle(fontSize: 11));
          }
        } else {
          cellContent = const SizedBox.shrink(); // 空セル
        }
        
        cells.add(DataCell(cellContent));
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