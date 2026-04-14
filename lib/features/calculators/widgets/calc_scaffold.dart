import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Common dark-themed scaffold used by every calculator screen.
class CalcScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CalcScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(title, style: AppTypography.cardTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: children,
          ),
        ),
      ),
    );
  }
}

class CalcField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;
  final bool allowDecimal;

  const CalcField({
    super.key,
    required this.label,
    required this.suffix,
    required this.controller,
    this.allowDecimal = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.numberWithOptions(
                        decimal: allowDecimal),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          allowDecimal ? RegExp(r'[\d.]') : RegExp(r'\d')),
                    ],
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w600),
                    cursorColor: AppColors.primaryRed,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    suffix,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CalcSegment<T> extends StatelessWidget {
  final String label;
  final List<T> options;
  final String Function(T) display;
  final T value;
  final ValueChanged<T> onChanged;

  const CalcSegment({
    super.key,
    required this.label,
    required this.options,
    required this.display,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: Row(
              children: options.map((opt) {
                final selected = opt == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryRed
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        display(opt),
                        style: AppTypography.caption.copyWith(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  final String? headline;
  final List<ResultRow> rows;
  final String? footnote;

  const ResultCard({
    super.key,
    this.headline,
    required this.rows,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headline != null) ...[
            Text(
              headline!,
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.label,
                        style: AppTypography.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      r.value,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: r.emphasize
                            ? AppColors.primaryRed
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )),
          if (footnote != null) ...[
            const SizedBox(height: 10),
            Text(
              footnote!,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class ResultRow {
  final String label;
  final String value;
  final bool emphasize;
  const ResultRow(this.label, this.value, {this.emphasize = false});
}
