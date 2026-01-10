import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/constraint_request.dart';
import '../../models/staff.dart';
import '../../providers/constraint_request_provider.dart';
import '../../providers/staff_provider.dart';
import '../../services/analytics_service.dart';
import '../../widgets/constraint_request_card.dart';

/// 制約承認画面（管理者専用）
class ConstraintApprovalScreen extends StatefulWidget {
  final AppUser appUser;
  final int initialTabIndex;

  const ConstraintApprovalScreen({
    super.key,
    required this.appUser,
    this.initialTabIndex = 0,
  });

  @override
  State<ConstraintApprovalScreen> createState() => _ConstraintApprovalScreenState();
}

class _ConstraintApprovalScreenState extends State<ConstraintApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isApproving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('constraint_approval_screen');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 一括承認を実行
  Future<void> _approveAll(
    List<ConstraintRequest> requests,
    Map<String, Staff> staffMap,
  ) async {
    if (requests.isEmpty) return;

    setState(() {
      _isApproving = true;
    });

    try {
      final requestProvider = context.read<ConstraintRequestProvider>();
      final userId = widget.appUser.uid;

      final approvedCount = await requestProvider.approveAllRequests(
        requests,
        userId,
        staffMap,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$approvedCount件の申請を承認しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApproving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConstraintRequestProvider, StaffProvider>(
      builder: (context, requestProvider, staffProvider, child) {
        final pendingRequests = requestProvider.pendingRequests;
        final approvedRequests = requestProvider.approvedRequests;

        // スタッフ情報をマップで保持（高速検索用）
        final staffMap = <String, Staff>{};
        for (final staff in staffProvider.staff) {
          staffMap[staff.id] = staff;
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('制約承認', style: TextStyle(fontSize: 18)),
            toolbarHeight: 48,
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('承認待ち'),
                      if (pendingRequests.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${pendingRequests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: '承認履歴'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 承認待ちタブ
              _buildPendingTab(pendingRequests, staffMap),
              // 承認履歴タブ
              _buildHistoryTab(approvedRequests, staffMap, requestProvider),
            ],
          ),
        );
      },
    );
  }

  /// 承認待ちタブの内容
  Widget _buildPendingTab(
    List<ConstraintRequest> pendingRequests,
    Map<String, Staff> staffMap,
  ) {
    if (pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '承認待ちの申請はありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // 申請日時の新しい順にソート
    final sortedRequests = List<ConstraintRequest>.from(pendingRequests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        // 一括承認ボタン
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: _isApproving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () => _approveAll(pendingRequests, staffMap),
                  icon: const Icon(Icons.done_all),
                  label: Text('すべて承認（${pendingRequests.length}件）'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
        ),
        // 申請リスト
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedRequests.length,
            itemBuilder: (context, index) {
              final request = sortedRequests[index];
              final staff = staffMap[request.staffId];

              if (staff == null) {
                return const SizedBox.shrink();
              }

              return ConstraintRequestCard(
                request: request,
                staff: staff,
                appUser: widget.appUser,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 承認履歴タブの内容
  Widget _buildHistoryTab(
    List<ConstraintRequest> approvedRequests,
    Map<String, Staff> staffMap,
    ConstraintRequestProvider requestProvider,
  ) {
    if (approvedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '承認履歴はありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // すでにapprovedAtでソートされているので、ソートは不要
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: approvedRequests.length + 1, // +1 for "もっと見る" button
      itemBuilder: (context, index) {
        // 最後のアイテムは「もっと見る」ボタン
        if (index == approvedRequests.length) {
          if (!requestProvider.hasMoreApproved) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: requestProvider.isLoadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => requestProvider.loadMoreApproved(),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('もっと見る'),
                    ),
            ),
          );
        }

        final request = approvedRequests[index];
        final staff = staffMap[request.staffId];

        if (staff == null) {
          return const SizedBox.shrink();
        }

        return _buildHistoryCard(request, staff);
      },
    );
  }

  /// 処理履歴カードを構築（承認/却下を区別）
  Widget _buildHistoryCard(ConstraintRequest request, Staff staff) {
    final isRejected = request.status == ConstraintRequest.statusRejected;
    final statusColor = isRejected ? Colors.red : Colors.green;
    final statusText = isRejected ? '却下' : '承認済み';
    final statusIcon = isRejected ? Icons.close : Icons.check;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // スタッフ名と処理日時
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  staff.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (request.approvedAt != null)
                  Text(
                    _formatDateTime(request.approvedAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // ステータス（承認/却下）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor.shade700),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 申請詳細
            Text(
              _getRequestDescription(request),
              style: const TextStyle(fontSize: 14),
            ),
            // 却下理由（却下の場合のみ）
            if (isRejected && request.rejectedReason != null && request.rejectedReason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '却下理由: ${request.rejectedReason}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                ),
              ),
            ],
            const SizedBox(height: 4),
            // 申請日時
            Text(
              '申請日時: ${_formatDateTime(request.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 日時をフォーマット
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 申請内容の説明を取得
  String _getRequestDescription(ConstraintRequest request) {
    final action = request.isDelete ? '削除' : '追加';

    switch (request.requestType) {
      case ConstraintRequest.typeWeekday:
        final weekdayName = _getWeekdayName(request.weekday);
        return '曜日の休み希望: $weekdayName ($action)';
      case ConstraintRequest.typeSpecificDay:
        if (request.specificDate != null) {
          final date = request.specificDate!;
          return '特定日の休み希望: ${date.year}/${date.month}/${date.day} ($action)';
        }
        return '特定日の休み希望 ($action)';
      case ConstraintRequest.typeShiftType:
        return 'シフトタイプ: ${request.shiftType ?? ''} ($action)';
      case ConstraintRequest.typeMaxShiftsPerMonth:
        return '月間最大シフト数: ${request.maxShiftsPerMonth ?? 0}回';
      case ConstraintRequest.typeHoliday:
        return '祝日の休み: ${request.holidaysOff == true ? '希望する' : '希望しない'}';
      case ConstraintRequest.typePreferredDate:
        if (request.specificDate != null) {
          final date = request.specificDate!;
          return '勤務希望日: ${date.year}/${date.month}/${date.day} ($action)';
        }
        return '勤務希望日 ($action)';
      default:
        return '不明な申請タイプ';
    }
  }

  /// 曜日番号から曜日名を取得
  String _getWeekdayName(int? weekday) {
    const weekdays = ['', '月', '火', '水', '木', '金', '土', '日'];
    if (weekday != null && weekday >= 1 && weekday <= 7) {
      return '${weekdays[weekday]}曜日';
    }
    return '不明';
  }
}
