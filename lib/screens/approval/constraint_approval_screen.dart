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

  const ConstraintApprovalScreen({
    super.key,
    required this.appUser,
  });

  @override
  State<ConstraintApprovalScreen> createState() => _ConstraintApprovalScreenState();
}

class _ConstraintApprovalScreenState extends State<ConstraintApprovalScreen> {
  @override
  void initState() {
    super.initState();
    // Analytics: 画面表示イベント
    AnalyticsService.logScreenView('constraint_approval_screen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('制約承認', style: TextStyle(fontSize: 18)),
        toolbarHeight: 48,
      ),
      body: Consumer2<ConstraintRequestProvider, StaffProvider>(
        builder: (context, requestProvider, staffProvider, child) {
          // 承認待ちの申請のみ取得
          final pendingRequests = requestProvider.pendingRequests;

          // スタッフ情報をマップで保持（高速検索用）
          final staffMap = <String, Staff>{};
          for (final staff in staffProvider.staff) {
            staffMap[staff.id] = staff;
          }

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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
          );
        },
      ),
    );
  }
}
