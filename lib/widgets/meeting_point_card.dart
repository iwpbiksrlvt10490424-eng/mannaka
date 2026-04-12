import 'package:flutter/material.dart';
import '../models/meeting_point.dart';
import '../theme/app_theme.dart';

class MeetingPointCard extends StatelessWidget {
  const MeetingPointCard({
    super.key,
    required this.point,
    required this.rank,
    required this.isSelected,
    required this.onTap,
  });

  final MeetingPoint point;
  final int rank;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${point.stationName}駅、平均${point.averageMinutes.toStringAsFixed(0)}分、${isSelected ? "選択中" : ""}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Rank badge（ソリッドカラー）
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: rank == 1 ? AppColors.primary : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank == 1 ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.train_rounded, size: 26, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${point.stationName}駅',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '平均 ${point.averageMinutes.toStringAsFixed(0)}分 · 最大 ${point.maxMinutes}分',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  _FairnessLabel(score: point.fairnessScore),
                ],
              ),
              const SizedBox(height: 12),
              // Participant times
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: point.participantTimes.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${e.key} ${e.value}分',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _FairnessLabel extends StatelessWidget {
  const _FairnessLabel({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (score >= 0.85) {
      color = const Color(0xFF059669);
      label = '全員に便利';
    } else if (score >= 0.65) {
      color = AppColors.textSecondary;
      label = 'バランス良好';
    } else {
      color = const Color(0xFFD97706);
      label = '少し偏りあり';
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
