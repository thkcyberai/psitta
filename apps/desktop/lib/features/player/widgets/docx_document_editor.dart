import 'package:flutter/material.dart';

import '../../../data/models/psitta_document.dart';

class DocxDocumentEditor extends StatelessWidget {
  const DocxDocumentEditor({
    super.key,
    required this.document,
    required this.controllers,
    this.error,
    this.isSaving = false,
    this.onChanged,
  });

  final PsittaDocument document;
  final Map<String, TextEditingController> controllers;
  final String? error;
  final bool isSaving;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];

    if (error != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (isSaving) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Saving document...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final block in document.blocks) {
      final controller = controllers[block.blockId];
      if (controller == null) continue;

      children.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: block.type == DocBlockType.heading ? 16 : 8,
          ),
          child: _DocxEditableBlock(
            block: block,
            controller: controller,
            enabled: !isSaving,
            onChanged: onChanged,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _DocxEditableBlock extends StatelessWidget {
  const _DocxEditableBlock({
    required this.block,
    required this.controller,
    required this.enabled,
    this.onChanged,
  });

  final DocBlock block;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = _styleForBlock(theme, block);
    final field = TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      maxLines: null,
      minLines: 1,
      mouseCursor: SystemMouseCursors.text,
      style: baseStyle,
      onChanged: (_) => onChanged?.call(),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
      ),
    );

    if (block.type == DocBlockType.listItem) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: Text(
              '\u2022',
              style: baseStyle,
            ),
          ),
          Expanded(child: field),
        ],
      );
    }

    return field;
  }

  TextStyle _styleForBlock(ThemeData theme, DocBlock block) {
    switch (block.type) {
      case DocBlockType.heading:
        switch (block.level) {
          case 1:
            return theme.textTheme.headlineMedium?.copyWith(height: 1.6) ??
                const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                );
          case 2:
            return theme.textTheme.headlineSmall?.copyWith(height: 1.6) ??
                const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                );
          default:
            return theme.textTheme.titleLarge?.copyWith(height: 1.6) ??
                const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                );
        }
      case DocBlockType.listItem:
        return theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontSize: 16,
            ) ??
            const TextStyle(fontSize: 16, height: 1.6);
      case DocBlockType.paragraph:
        return theme.textTheme.bodyLarge?.copyWith(
              height: 1.8,
              fontSize: 16,
            ) ??
            const TextStyle(fontSize: 16, height: 1.8);
    }
  }
}
