import 'package:flutter/material.dart';

import '../models/assignment_strategy.dart';
import '../models/shift_plan.dart';
import '../services/shift_plan_service.dart';

/// プラン切替ダイアログ
class RestoreDialog extends StatefulWidget {
  final List<ShiftPlan> plans;
  final DateTime focusedDay;
  final String teamId;
  final Function(ShiftPlan) onRestore;

  const RestoreDialog({
    super.key,
    required this.plans,
    required this.focusedDay,
    required this.teamId,
    required this.onRestore,
  });

  @override
  State<RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<RestoreDialog> {
  ShiftPlan? _selectedPlan;
  List<ShiftPlan> _restorablePlans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestorablePlans();
  }

  Future<void> _loadRestorablePlans() async {
    final planService = ShiftPlanService(teamId: widget.teamId);
    final month = '${widget.focusedDay.year}-${widget.focusedDay.month}';

    // 現在有効なplan_idを取得
    final currentPlanId = await planService.getActivePlanId(month);

    // 現在有効な案以外のプランを取得
    final restorablePlans = widget.plans.where((plan) => plan.planId != currentPlanId).toList();

    setState(() {
      _restorablePlans = restorablePlans;
      _selectedPlan = restorablePlans.isNotEmpty ? restorablePlans.first : null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_restorablePlans.isEmpty) {
      return AlertDialog(
        title: const Text('プラン切替'),
        content: const Text('切り替え可能なプランがありません'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('プラン切替'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('切り替え先のプランを選択してください'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<ShiftPlan>(
                value: _selectedPlan,
                isExpanded: true,
                underline: const SizedBox(),
                itemHeight: 60,
                items: _restorablePlans.asMap().entries.map((entry) {
                  final plan = entry.value;
                  final strategyName = AssignmentStrategy.getDisplayNameFromString(plan.strategy);
                  final dateStr = '${plan.createdAt.year}/${plan.createdAt.month.toString().padLeft(2, '0')}/'
                      '${plan.createdAt.day.toString().padLeft(2, '0')} '
                      '${plan.createdAt.hour.toString().padLeft(2, '0')}:'
                      '${plan.createdAt.minute.toString().padLeft(2, '0')}';

                  return DropdownMenuItem(
                    value: plan,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                            children: [
                              TextSpan(
                                text: plan.planId,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              TextSpan(
                                text: '　$dateStr',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$strategyName　${plan.totalShifts}件',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlan = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (_selectedPlan != null) {
              widget.onRestore(_selectedPlan!);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('切替'),
        ),
      ],
    );
  }
}
