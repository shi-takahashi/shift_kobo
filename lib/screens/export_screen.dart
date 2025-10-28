import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;
import 'dart:io';
import 'dart:typed_data';
import '../providers/shift_provider.dart';
import '../providers/staff_provider.dart';
import '../models/shift.dart';
import '../models/staff.dart';
import '../providers/shift_time_provider.dart';
import '../models/shift_time_setting.dart';

class ExportScreen extends StatefulWidget {
  final DateTime? initialMonth;
  
  const ExportScreen({super.key, this.initialMonth});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  late DateTime _selectedMonth;
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    // 初期月を設定（渡されなければ現在月）
    _selectedMonth = widget.initialMonth ?? DateTime.now();
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
          // 操作ボタン（Web版では非表示）
          if (!kIsWeb && !_isProcessing)
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
          // Web版での案内メッセージ
          if (kIsWeb)
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Web版では保存・共有機能は利用できません。\nスクリーンショットをご利用ください。',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
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
              title: const Text('月を選択', style: TextStyle(fontSize: 18)), // タイトル文字を小さく
              titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 8), // タイトル余白を縮小
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20), // コンテンツ余白調整
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.65, // 横幅を65%に
                height: MediaQuery.of(context).size.height * 0.55, // 高さを55%に
                child: Row(
                  children: [
                    // 年選択（左側）
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('年', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedYear--;
                                  });
                                },
                              ),
                              Text(
                                '$selectedYear',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedYear++;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 32),
                    // 月選択グリッド（右側）
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          const Text('月', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 4, // 4列に戻す
                              mainAxisSpacing: 4, // 縦間隔を小さく
                              crossAxisSpacing: 6, // 横間隔
                              childAspectRatio: 2.2, // やや横長でコンパクトに
                              shrinkWrap: true,
                              children: List.generate(12, (index) {
                                final month = index + 1;
                                final isSelected = selectedYear == _selectedMonth.year && 
                                                 month == _selectedMonth.month;
                                
                                return GestureDetector(
                                  onTap: () {
                                    final newMonth = DateTime(selectedYear, month, 1);
                                    setState(() {
                                      _selectedMonth = newMonth;
                                    });
                                    // ShiftProviderに表示月を通知（データ取得範囲を更新）
                                    Provider.of<ShiftProvider>(context, listen: false).setCurrentMonth(newMonth);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
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
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
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
      final staffIds = _getStaffIdsWithShifts(shifts);
      for (final staffId in staffIds) {
        final staffData = staffProvider.getStaffById(staffId);
        final row = <excel.CellValue?>[
          excel.TextCellValue(_getStaffDisplayName(staffData, staffId))
        ];

        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
          final dayShifts = shifts[date] ?? [];
          final staffShifts = dayShifts.where((s) => s.staffId == staffId).toList();

          String cellValue = '';
          if (staffShifts.isNotEmpty) {
            if (staffShifts.length == 1) {
              // シフトが1つの場合は通常表示
              final staffShift = staffShifts.first;
              final setting = shiftTimeProvider.settings
                  .where((s) => s.displayName == staffShift.shiftType)
                  .firstOrNull;
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
            } else {
              // シフトが複数の場合は「日・夜」のように表示
              final shiftChars = <String>[];
              final timeDifferences = <String>[];

              for (final staffShift in staffShifts) {
                final setting = shiftTimeProvider.settings
                    .where((s) => s.displayName == staffShift.shiftType)
                    .firstOrNull;
                if (setting != null) {
                  final shiftChar = setting.displayName.isNotEmpty ? setting.displayName[0] : '?';

                  // 標準時間と異なるかチェック
                  final actualStartTime = DateFormat('HH:mm').format(staffShift.startTime);
                  final actualEndTime = DateFormat('HH:mm').format(staffShift.endTime);
                  final isDifferentTime = actualStartTime != setting.startTime || actualEndTime != setting.endTime;

                  if (isDifferentTime) {
                    timeDifferences.add('$shiftChar($actualStartTime-$actualEndTime)');
                  } else {
                    shiftChars.add(shiftChar);
                  }
                }
              }

              // 時間差異がある場合は詳細表示、なければシンプルに
              if (timeDifferences.isNotEmpty) {
                cellValue = timeDifferences.join('・');
              } else {
                cellValue = shiftChars.join('・');
              }
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
    // データがない場合のチェック
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final shifts = shiftProvider.getMonthlyShiftMap(_selectedMonth.year, _selectedMonth.month);
    final staffIds = _getStaffIdsWithShifts(shifts);

    if (staffIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${DateFormat('yyyy年MM月').format(_selectedMonth)}のシフトデータがありません'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
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
    // データがない場合のチェック
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final shifts = shiftProvider.getMonthlyShiftMap(_selectedMonth.year, _selectedMonth.month);
    final staffIds = _getStaffIdsWithShifts(shifts);

    if (staffIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${DateFormat('yyyy年MM月').format(_selectedMonth)}のシフトデータがありません'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
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
      final staffIds = _getStaffIdsWithShifts(shifts);
      for (final staffId in staffIds) {
        final staffData = staffProvider.getStaffById(staffId);
        final row = <excel.CellValue?>[
          excel.TextCellValue(_getStaffDisplayName(staffData, staffId))
        ];

        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
          final dayShifts = shifts[date] ?? [];
          final staffShifts = dayShifts.where((s) => s.staffId == staffId).toList();

          String cellValue = '';
          if (staffShifts.isNotEmpty) {
            if (staffShifts.length == 1) {
              // シフトが1つの場合は通常表示
              final staffShift = staffShifts.first;
              final setting = shiftTimeProvider.settings
                  .where((s) => s.displayName == staffShift.shiftType)
                  .firstOrNull;
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
            } else {
              // シフトが複数の場合は「日・夜」のように表示
              final shiftChars = <String>[];
              final timeDifferences = <String>[];

              for (final staffShift in staffShifts) {
                final setting = shiftTimeProvider.settings
                    .where((s) => s.displayName == staffShift.shiftType)
                    .firstOrNull;
                if (setting != null) {
                  final shiftChar = setting.displayName.isNotEmpty ? setting.displayName[0] : '?';

                  // 標準時間と異なるかチェック
                  final actualStartTime = DateFormat('HH:mm').format(staffShift.startTime);
                  final actualEndTime = DateFormat('HH:mm').format(staffShift.endTime);
                  final isDifferentTime = actualStartTime != setting.startTime || actualEndTime != setting.endTime;

                  if (isDifferentTime) {
                    timeDifferences.add('$shiftChar($actualStartTime-$actualEndTime)');
                  } else {
                    shiftChars.add(shiftChar);
                  }
                }
              }

              // 時間差異がある場合は詳細表示、なければシンプルに
              if (timeDifferences.isNotEmpty) {
                cellValue = timeDifferences.join('・');
              } else {
                cellValue = shiftChars.join('・');
              }
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

    // その月にシフトがあるスタッフIDを抽出
    final staffIds = _getStaffIdsWithShifts(shifts);

    // シフトがない場合のメッセージ表示
    if (staffIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '${DateFormat('yyyy年MM月').format(_selectedMonth)}のシフトデータがありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'シフト管理画面でシフトを登録してください',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: _buildCalendarTable(shifts, staffIds, staffProvider),
      ),
    );
  }

  // その月にシフトがあるスタッフIDを抽出
  List<String> _getStaffIdsWithShifts(Map<DateTime, List<Shift>> shifts) {
    final staffIds = <String>{};

    // その月の全シフトからスタッフIDを収集
    for (final dayShifts in shifts.values) {
      for (final shift in dayShifts) {
        staffIds.add(shift.staffId);
      }
    }

    return staffIds.toList();
  }

  /// スタッフ名を取得（削除済みスタッフの場合は「不明」表示）
  String _getStaffDisplayName(Staff? staff, String staffId) {
    if (staff == null) {
      return '不明';
    }
    return staff.name;
  }

  Widget _buildCalendarTable(Map<DateTime, List<Shift>> shifts, List<String> staffIds, StaffProvider staffProvider) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

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
      rows: _buildStaffRows(daysInMonth, shifts, staffIds, staffProvider),
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
      final isSaturday = date.weekday == 6;
      final isSunday = date.weekday == 7;
      final isHoliday = holiday_jp.isHoliday(date);

      Color dayColor = Colors.black;
      Color weekdayColor = Colors.grey;

      if (isHoliday || isSunday) {
        dayColor = Colors.red;
        weekdayColor = Colors.red;
      } else if (isSaturday) {
        dayColor = Colors.blue;
        weekdayColor = Colors.blue;
      }

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
                  color: dayColor,
                ),
              ),
              Text(
                weekday,
                style: TextStyle(
                  fontSize: 9,
                  color: weekdayColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return columns;
  }

  List<DataRow> _buildStaffRows(int daysInMonth, Map<DateTime, List<Shift>> shifts, List<String> staffIds, StaffProvider staffProvider) {
    final shiftTimeProvider = Provider.of<ShiftTimeProvider>(context, listen: false);
    final rows = <DataRow>[];

    for (final staffId in staffIds) {
      final staffData = staffProvider.getStaffById(staffId);
      final cells = <DataCell>[
        DataCell(
          Text(
            _getStaffDisplayName(staffData, staffId),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ];

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        final dayShifts = shifts[date] ?? [];
        final staffShifts = dayShifts.where((s) => s.staffId == staffId).toList();

        Widget cellContent;
        if (staffShifts.isNotEmpty) {
          if (staffShifts.length == 1) {
            // シフトが1つの場合は通常表示
            final staffShift = staffShifts.first;
            final setting = shiftTimeProvider.settings
                .where((s) => s.displayName == staffShift.shiftType)
                .firstOrNull;
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
            // シフトが複数の場合は「日・夜」のように表示
            final shiftChars = <String>[];
            bool hasTimeDifference = false;

            for (final staffShift in staffShifts) {
              final setting = shiftTimeProvider.settings
                  .where((s) => s.displayName == staffShift.shiftType)
                  .firstOrNull;
              if (setting != null) {
                final shiftChar = setting.displayName.isNotEmpty ? setting.displayName[0] : '?';
                shiftChars.add(shiftChar);

                // いずれかのシフトが標準時間と異なるかチェック
                final actualStartTime = DateFormat('HH:mm').format(staffShift.startTime);
                final actualEndTime = DateFormat('HH:mm').format(staffShift.endTime);
                if (actualStartTime != setting.startTime || actualEndTime != setting.endTime) {
                  hasTimeDifference = true;
                }
              }
            }

            cellContent = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shiftChars.join('・'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (hasTimeDifference) ...[
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

    // その月にシフトがあるスタッフIDを抽出
    final staffIds = _getStaffIdsWithShifts(shifts);

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
            child: _buildCalendarTable(shifts, staffIds, staffProvider),
          ),
        ],
      ),
    );
  }
}