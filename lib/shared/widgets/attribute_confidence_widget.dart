import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';

class AttributeConfidenceWidget extends StatelessWidget {
  final AttributeField field;
  final VoidCallback? onEdit;

  const AttributeConfidenceWidget({
    super.key,
    required this.field,
    this.onEdit,
  });

  Color get _confidenceColor {
    if (field.confidence >= 0.8) return AppColors.confidenceHigh;
    if (field.confidence >= 0.5) return AppColors.confidenceMedium;
    return AppColors.confidenceLow;
  }

  String get _confidenceLabel {
    if (field.confidence >= 0.8) return 'उच्च';
    if (field.confidence >= 0.5) return 'मध्यम';
    return 'निम्न';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = field.value != null && field.value!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValue
              ? _confidenceColor.withOpacity(0.25)
              : AppColors.accentRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Confidence indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _confidenceColor.withOpacity(0.12),
              border: Border.all(color: _confidenceColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                hasValue ? '${(field.confidence * 100).toInt()}%' : '?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _confidenceColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Field details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      field.labelHi,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '· ${field.labelEn}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                    if (field.isRequired) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          color: AppColors.accentRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                hasValue
                    ? Text(
                        field.value!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.accentRed.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'ℹ️  जानकारी चाहिए · Missing',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.accentRed,
                          ),
                        ),
                      ),
              ],
            ),
          ),
          // Edit button
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: AppColors.textHint, size: 15),
              ),
            ),
        ],
      ),
    );
  }
}
