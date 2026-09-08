import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';

class VerificationStatusChip extends StatelessWidget {
  final VerificationStatus status;
  final bool compact;

  const VerificationStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: config.color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            compact ? config.shortLabel : config.label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _ChipConfig _getConfig(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.aiGenerated:
        return _ChipConfig(AppColors.statusGenerated, 'AI Generated', 'AI');
      case VerificationStatus.artisanReviewed:
        return _ChipConfig(AppColors.statusReviewed, 'In Review', 'Review');
      case VerificationStatus.approved:
        return _ChipConfig(AppColors.statusApproved, '✓ Approved', '✓');
      case VerificationStatus.rejected:
        return _ChipConfig(AppColors.accentRed, 'Rejected', 'Rej');
    }
  }
}

class _ChipConfig {
  final Color color;
  final String label;
  final String shortLabel;
  const _ChipConfig(this.color, this.label, this.shortLabel);
}
