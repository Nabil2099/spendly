import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../ai_advisor/data/gemini_chat_service.dart';
import '../data/expense_model.dart';
import 'expense_cubit.dart';
import 'widgets/category_badge.dart';
import 'widgets/receipt_scanner_helper.dart';

/// Single screen used for both adding a new expense and editing an existing one.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.existing, this.initialDraft});

  final Expense? existing;
  final ParsedExpenseDraft? initialDraft;

  bool get isEditing => existing != null;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late ExpenseCategory _selectedCategory;
  late DateTime _selectedDate;
  late List<ExpenseItem> _items;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final draft = widget.initialDraft;
    final initialMinor = existing?.amountMinor ?? draft?.amountMinor;

    _amountController = TextEditingController(
      text: initialMinor != null
          ? MoneyFormatter.formatEditable(initialMinor)
          : '',
    );
    _titleController = TextEditingController(
      text: existing?.title ?? draft?.title ?? '',
    );
    _noteController = TextEditingController(
      text: existing?.note ?? draft?.note ?? '',
    );
    _selectedCategory =
        existing?.category ??
        draft?.category ??
        context.read<ExpenseCubit>().state.lastCategory;
    _selectedDate = existing?.date ?? draft?.date ?? DateTime.now();
    _items = List<ExpenseItem>.from(existing?.items ?? const []);
  }

  void _syncAmountFromItems() {
    if (_items.isEmpty) return;
    final total = _items.fold<int>(0, (sum, item) => sum + item.amountMinor);
    _amountController.text = MoneyFormatter.formatEditable(total);
  }

  Future<void> _addOrEditItem({int? index}) async {
    final existingItem = index != null ? _items[index] : null;
    final result = await showDialog<ExpenseItem>(
      context: context,
      builder: (_) => _ItemEditorDialog(
        initial: existingItem,
        defaultCategory: _selectedCategory,
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _items[index] = result;
      } else {
        _items.add(result);
      }
      _syncAmountFromItems();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _syncAmountFromItems();
    });
  }

  Future<void> _scanReceipt() async {
    try {
      final drafts = await pickAndScanReceipt(
        context,
        onParsingStarted: () {
          if (mounted) setState(() => _isScanning = true);
        },
      );
      if (!mounted) return;
      setState(() => _isScanning = false);
      if (drafts == null || drafts.isEmpty) return;

      if (drafts.length > 1) {
        final savedAll = await showReceiptItemsSheet(context, drafts);
        if (savedAll == true && mounted) {
          context.pop(true);
        }
        return;
      }

      final draft = drafts.first;
      if (draft.amountMinor != null) {
        _amountController.text = MoneyFormatter.formatEditable(
          draft.amountMinor!,
        );
      }
      if (draft.title.isNotEmpty) {
        _titleController.text = draft.title;
      }
      if (draft.note.isNotEmpty) {
        _noteController.text = draft.note;
      }
      setState(() {
        _selectedCategory = draft.category;
        _selectedDate = draft.date;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt scanned! Review details and tap Save.'),
        ),
      );
    } on GeminiFailure catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not scan receipt. Try again.')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amountMinor = MoneyFormatter.parseToMinor(_amountController.text);
    if (amountMinor == null) return;

    final cubit = context.read<ExpenseCubit>();
    final success = await cubit.saveExpense(
      existing: widget.existing,
      title: _titleController.text,
      amountMinor: amountMinor,
      category: _selectedCategory,
      date: _selectedDate,
      note: _noteController.text,
      items: _items,
    );

    if (!mounted) return;
    if (success) {
      context.pop(true);
    } else {
      final msg =
          cubit.state.errorMessage ?? 'Could not save expense. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select((ExpenseCubit c) => c.state.isSaving);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Expense' : 'Add Expense'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.isEditing) ...[
                      OutlinedButton.icon(
                        onPressed: (isSaving || _isScanning)
                            ? null
                            : _scanReceipt,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.document_scanner_outlined,
                                color: AppColors.slateBlue,
                              ),
                        label: Text(
                          _isScanning
                              ? 'Scanning receipt with AI...'
                              : 'Scan Receipt with AI',
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _AmountCard(
                      controller: _amountController,
                      enabled: !isSaving && !_isScanning,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Category',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CategoryGrid(
                      selected: _selectedCategory,
                      onSelected: isSaving
                          ? null
                          : (cat) => setState(() => _selectedCategory = cat),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Title',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      enabled: !isSaving,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'e.g. Lunch, Groceries, Metro ticket',
                        prefixIcon: const Icon(Icons.local_offer_outlined),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _titleController,
                          builder: (context, value, _) {
                            if (value.text.isEmpty || isSaving) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              onPressed: _titleController.clear,
                              icon: const Icon(Icons.close_rounded, size: 18),
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Title is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Date',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isSaving ? null : _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        child: Text(
                          DateFormat.yMMMd().format(_selectedDate),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Notes (optional)',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteController,
                      enabled: !isSaving,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Business lunch with team...',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ReceiptItemsEditor(
                      items: _items,
                      enabled: !isSaving,
                      onAdd: () => _addOrEditItem(),
                      onEdit: (index) => _addOrEditItem(index: index),
                      onRemove: _removeItem,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => context.pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isSaving ? null : _submit,
                            child: isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(widget.isEditing ? 'Update' : 'Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: context.greenTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Amount (EGP)',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: '0.00',
              hintStyle: TextStyle(
                color: AppColors.mutedSage,
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            validator: (value) {
              if (MoneyFormatter.parseToMinor(value ?? '') == null) {
                return 'Enter a valid positive amount (e.g. 85.50).';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onSelected});

  final ExpenseCategory selected;
  final ValueChanged<ExpenseCategory>? onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 460 ? 4 : 3;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ExpenseCategory.values.map((category) {
            final isSelected = category == selected;
            return SizedBox(
              width: itemWidth,
              child: InkWell(
                onTap: onSelected == null ? null : () => onSelected!(category),
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? context.greenTint : context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : context.borderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: CategoryBadge(
                              category: category,
                              size: 38,
                              iconSize: 19,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -5,
                      right: -5,
                      child: AnimatedScale(
                        scale: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ReceiptItemsEditor extends StatelessWidget {
  const _ReceiptItemsEditor({
    required this.items,
    required this.enabled,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final List<ExpenseItem> items;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              items.isEmpty
                  ? 'Receipt Items (optional)'
                  : 'Receipt Items (${items.length})',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Item'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 34),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                return Column(
                  children: [
                    if (index > 0)
                      Divider(height: 1, color: context.borderColor),
                    ListTile(
                      dense: true,
                      onTap: enabled ? () => onEdit(index) : null,
                      leading: CategoryBadge(
                        category: item.category,
                        size: 32,
                        iconSize: 16,
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            MoneyFormatter.formatEgp(item.amountMinor),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Remove item',
                            onPressed: enabled ? () => onRemove(index) : null,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemEditorDialog extends StatefulWidget {
  const _ItemEditorDialog({this.initial, required this.defaultCategory});

  final ExpenseItem? initial;
  final ExpenseCategory defaultCategory;

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late ExpenseCategory _category;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initial?.title ?? '',
    );
    _amountController = TextEditingController(
      text: widget.initial != null
          ? MoneyFormatter.formatEditable(widget.initial!.amountMinor)
          : '',
    );
    _category = widget.initial?.category ?? widget.defaultCategory;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final minor = MoneyFormatter.parseToMinor(_amountController.text);
    if (minor == null) return;
    Navigator.of(context).pop(
      ExpenseItem(
        title: _titleController.text.trim(),
        amountMinor: minor,
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Receipt Item' : 'Edit Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  hintText: 'e.g. Milk, Coffee',
                ),
                validator: (val) => (val ?? '').trim().isEmpty
                    ? 'Item name is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (EGP)',
                  prefixText: 'EGP ',
                ),
                validator: (val) =>
                    MoneyFormatter.parseToMinor(val ?? '') == null
                    ? 'Enter a valid positive amount.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ExpenseCategory.values
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat.label),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
