import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../ai_advisor/data/gemini_chat_service.dart';
import '../../data/expense_model.dart';
import '../expense_cubit.dart';
import 'category_badge.dart';

/// Prompts for Camera or Gallery, then extracts 1 or more receipt items via Gemini.
Future<List<ParsedExpenseDraft>?> pickAndScanReceipt(
  BuildContext context, {
  VoidCallback? onParsingStarted,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: context.cardBg,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.primaryGreen,
            ),
            title: Text(
              'Take a photo of receipt',
              style: TextStyle(
                color: sheetContext.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_library_rounded,
              color: AppColors.slateBlue,
            ),
            title: Text(
              'Choose receipt from gallery',
              style: TextStyle(
                color: sheetContext.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return null;

  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 85,
  );
  if (file == null) return null;

  onParsingStarted?.call();
  final bytes = await file.readAsBytes();
  final mime = file.path.toLowerCase().endsWith('.png')
      ? 'image/png'
      : 'image/jpeg';

  return getIt<GeminiChatService>().parseExpenseFromReceipt(
    bytes,
    mimeType: mime,
  );
}

/// Shows extracted receipt items so the user can save all selected items at once
/// or tap an item to edit it individually.
Future<bool?> showReceiptItemsSheet(
  BuildContext context,
  List<ParsedExpenseDraft> items,
) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.cardBg,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReceiptItemsSheet(items: items),
  );
}

class _ReceiptItemsSheet extends StatefulWidget {
  const _ReceiptItemsSheet({required this.items});

  final List<ParsedExpenseDraft> items;

  @override
  State<_ReceiptItemsSheet> createState() => _ReceiptItemsSheetState();
}

class _ReceiptItemsSheetState extends State<_ReceiptItemsSheet> {
  late final TextEditingController _receiptTitleController;
  late final List<bool> _selected;
  bool _isSavingAll = false;

  @override
  void initState() {
    super.initState();
    final firstNote = widget.items.first.note.trim();
    _receiptTitleController = TextEditingController(
      text: firstNote.isNotEmpty ? firstNote : 'Receipt',
    );
    _selected = widget.items
        .map((item) => item.amountMinor != null && item.title.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _receiptTitleController.dispose();
    super.dispose();
  }

  int get _selectedCount => _selected.where((v) => v).length;

  int get _selectedTotalMinor {
    var sum = 0;
    for (var i = 0; i < widget.items.length; i++) {
      if (_selected[i]) {
        sum += widget.items[i].amountMinor ?? 0;
      }
    }
    return sum;
  }

  Future<void> _saveAsReceipt() async {
    if (_selectedCount == 0 || _isSavingAll) return;
    setState(() => _isSavingAll = true);

    final selectedItems = <ExpenseItem>[];
    final categoryTotals = <ExpenseCategory, int>{};
    DateTime? receiptDate;

    for (var i = 0; i < widget.items.length; i++) {
      if (!_selected[i]) continue;
      final item = widget.items[i];
      final minor = item.amountMinor;
      if (minor == null || minor <= 0 || item.title.trim().isEmpty) continue;
      selectedItems.add(
        ExpenseItem(
          title: item.title.trim(),
          amountMinor: minor,
          category: item.category,
        ),
      );
      categoryTotals[item.category] =
          (categoryTotals[item.category] ?? 0) + minor;
      receiptDate ??= item.date;
    }

    if (selectedItems.isEmpty) {
      setState(() => _isSavingAll = false);
      return;
    }

    var dominantCategory = selectedItems.first.category;
    var maxCatTotal = -1;
    for (final entry in categoryTotals.entries) {
      if (entry.value > maxCatTotal) {
        maxCatTotal = entry.value;
        dominantCategory = entry.key;
      }
    }

    final receiptTitle = _receiptTitleController.text.trim().isNotEmpty
        ? _receiptTitleController.text.trim()
        : 'Receipt';

    final ok = await context.read<ExpenseCubit>().saveExpense(
      title: receiptTitle,
      amountMinor: _selectedTotalMinor,
      category: dominantCategory,
      date: receiptDate ?? DateTime.now(),
      note: '${selectedItems.length} items',
      items: selectedItems,
    );

    if (!mounted) return;
    Navigator.of(context).pop(ok);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved "$receiptTitle" (${selectedItems.length} items).',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Receipt Items (${widget.items.length})',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    MoneyFormatter.formatEgp(_selectedTotalMinor),
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Uncheck items to skip, or tap an item to edit before saving.',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _receiptTitleController,
                enabled: !_isSavingAll,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Receipt Title',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.borderColor),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final canSelect =
                        item.amountMinor != null && item.title.isNotEmpty;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: _selected[index],
                        activeColor: AppColors.primaryGreen,
                        onChanged: (_isSavingAll || !canSelect)
                            ? null
                            : (val) =>
                                  setState(() => _selected[index] = val ?? false),
                      ),
                      title: Row(
                        children: [
                          CategoryBadge(
                            category: item.category,
                            size: 32,
                            iconSize: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title.isNotEmpty
                                      ? item.title
                                      : 'Unnamed item',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${item.category.label} · ${DateFormat.MMMd().format(item.date)}',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.amountMinor != null
                                ? MoneyFormatter.formatEgp(item.amountMinor!)
                                : '—',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      onTap: _isSavingAll
                          ? null
                          : () {
                              Navigator.of(context).pop(false);
                              context.push(AppRoutes.expenseNew, extra: item);
                            },
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: (_selectedCount == 0 || _isSavingAll)
                    ? null
                    : _saveAsReceipt,
                child: _isSavingAll
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save Receipt ($_selectedCount item${_selectedCount == 1 ? '' : 's'})',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
