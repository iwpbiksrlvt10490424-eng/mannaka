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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
                  // Rank badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: rank == 1 ? AppColors.primaryGradient : null,
                      color: rank == 1 ? null : Colors.grey.shade200,
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
                  Text(point.stationEmoji, style: const TextStyle(fontSize: 26)),
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
                  _FairnessChip(score: point.fairnessScore),
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${e.key} ${e.value}分',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              // Overall score bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: point.overallScore,
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FairnessChip extends StatelessWidget {
  const _FairnessChip({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (score >= 0.85) {
      color = const Color(0xFF10B981);
      label = '最公平';
    } else if (score >= 0.65) {
      color = const Color(0xFF3B82F6);
      label = 'フェア';
    } else {
      color = const Color(0xFFF59E0B);
      label = '要確認';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
