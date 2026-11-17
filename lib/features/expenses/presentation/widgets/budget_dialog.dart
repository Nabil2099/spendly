import 'package:flutter/material.dart';

import '../../../../core/utils/money_formatter.dart';

/// Prompts the user to set or update their monthly budget in EGP.
Future<int?> showBudgetDialog(
  BuildContext context, {
  int? currentLimitMinor,
  required String monthLabel,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _BudgetDialog(
      currentLimitMinor: currentLimitMinor,
      monthLabel: monthLabel,
    ),
  );
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({
    required this.currentLimitMinor,
    required this.monthLabel,
  });

  final int? currentLimitMinor;
  final String monthLabel;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentLimitMinor != null
          ? MoneyFormatter.formatEditable(widget.currentLimitMinor!)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final minor = MoneyFormatter.parseToMinor(_controller.text);
    if (minor != null) {
      Navigator.of(context).pop(minor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.monthLabel} Budget'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly limit (EGP)',
            hintText: 'e.g. 5000.00',
            prefixText: 'EGP ',
          ),
          validator: (value) {
            final minor = MoneyFormatter.parseToMinor(value ?? '');
            if (minor == null) {
              return 'Enter a valid positive amount.';
            }
            return null;
          },
          onFieldSubmitted: (_) => _save(),
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
