import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Drop zone overlay — shown when dragging files over the library.
///
/// Full-screen semi-transparent overlay with a dashed border visual
/// and "Drop files here" prompt. Disappears when drag exits or completes.
class DropZoneOverlay extends StatelessWidget {
  const DropZoneOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppColors.primary.withOpacity(0.08),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.5),
                width: 2,
              ),
              color: Colors.white.withOpacity(0.9),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.file_download_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Drop files to upload',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PDF, DOCX, TXT, Markdown, HTML',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
