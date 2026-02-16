import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Voice preview card — displays voice info with preview and select.
class VoicePreviewCard extends StatelessWidget {
  final String voiceName;
  final String voiceId;
  final String language;
  final String tier;
  final String gender;
  final bool isSelected;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  const VoicePreviewCard({
    super.key,
    required this.voiceName,
    required this.voiceId,
    required this.language,
    required this.tier,
    required this.gender,
    required this.isSelected,
    required this.onPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = tier == 'premium';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary : theme.dividerColor.withOpacity(0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.primary.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Voice info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          voiceName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PRO',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$language · $gender',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Preview button
              IconButton(
                icon: const Icon(Icons.volume_up_outlined, size: 20),
                onPressed: onPreview,
                tooltip: 'Preview voice',
              ),
              // Select indicator
              IconButton(
                icon: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 22,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                onPressed: onSelect,
                tooltip: isSelected ? 'Currently selected' : 'Select as default voice',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
