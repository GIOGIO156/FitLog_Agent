import 'package:flutter/material.dart';

import '../../core/localization/localization_extensions.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import '../../domain/models/food_item.dart';

class EditableFoodItemDraft {
  EditableFoodItemDraft({
    this.id,
    required this.name,
    required this.estimatedWeightG,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.notes,
  });

  factory EditableFoodItemDraft.fromFoodItem(FoodItem item) {
    return EditableFoodItemDraft(
      id: item.id,
      name: item.name,
      estimatedWeightG: _formatDecimal(item.estimatedWeightG),
      caloriesKcal: _formatDecimal(item.caloriesKcal),
      proteinG: _formatDecimal(item.proteinG),
      carbsG: _formatDecimal(item.carbsG),
      fatG: _formatDecimal(item.fatG),
      notes: item.notes,
    );
  }

  final int? id;
  String name;
  String estimatedWeightG;
  String caloriesKcal;
  String proteinG;
  String carbsG;
  String fatG;
  String notes;

  FoodItem toFoodItem() {
    return FoodItem(
      id: id,
      name: name.trim().isEmpty ? 'Unnamed item' : name.trim(),
      estimatedWeightG: NumberUtils.toDouble(estimatedWeightG),
      caloriesKcal: NumberUtils.toDouble(caloriesKcal),
      proteinG: NumberUtils.toDouble(proteinG),
      carbsG: NumberUtils.toDouble(carbsG),
      fatG: NumberUtils.toDouble(fatG),
      notes: notes.trim(),
    );
  }

  static String _formatDecimal(double value) => value.toStringAsFixed(1);
}

class FoodFormField extends StatelessWidget {
  const FoodFormField({
    super.key,
    this.controller,
    this.initialValue,
    required this.labelText,
    this.suffixText,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String labelText;
  final String? suffixText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final void Function(String value)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      decoration: InputDecoration(labelText: labelText, suffixText: suffixText),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }
}

class FoodDateTile extends StatelessWidget {
  const FoodDateTile({super.key, required this.date, required this.onChange});

  final String date;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(strings.date),
      subtitle: Text(DateUtilsX.formatReadable(date)),
      trailing: TextButton(onPressed: onChange, child: Text(strings.change)),
    );
  }
}

class FoodSaveButton extends StatelessWidget {
  const FoodSaveButton({
    super.key,
    required this.saving,
    required this.label,
    required this.onPressed,
  });

  final bool saving;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(saving ? strings.saving : label),
    );
  }
}
