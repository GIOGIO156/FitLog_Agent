import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import '../../domain/models/food_record.dart';
import 'food_form_support.dart';

class FoodDetailPage extends StatefulWidget {
  const FoodDetailPage({super.key, required this.recordId});

  final int recordId;

  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _mealNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _confidenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _date = DateUtilsX.todayKey();
  String _originalDate = DateUtilsX.todayKey();
  String _source = '';
  List<EditableFoodItemDraft> _items = <EditableFoodItemDraft>[];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _confidenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final strings = context.stringsRead;
    final record = await context
        .read<AppServices>()
        .foodRepository
        .getFoodRecordById(widget.recordId);

    if (!mounted) {
      return;
    }

    if (record == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.foodRecordNotFound)));
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _date = record.date;
      _originalDate = record.date;
      _source = record.source;
      _mealNameController.text = record.mealName;
      _weightController.text = record.totalWeightG.toStringAsFixed(1);
      _caloriesController.text = record.caloriesKcal.toStringAsFixed(1);
      _proteinController.text = record.proteinG.toStringAsFixed(1);
      _carbsController.text = record.carbsG.toStringAsFixed(1);
      _fatController.text = record.fatG.toStringAsFixed(1);
      _confidenceController.text = record.confidence?.toStringAsFixed(2) ?? '';
      _notesController.text = record.estimationNotes;
      _items = record.items.map(EditableFoodItemDraft.fromFoodItem).toList();
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateUtilsX.parseDay(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() => _date = DateUtilsX.formatDate(selected));
    }
  }

  Future<void> _save() async {
    final strings = context.stringsRead;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final updated = FoodRecord(
        id: widget.recordId,
        date: _date,
        mealName: _mealNameController.text.trim(),
        totalWeightG: NumberUtils.toDouble(_weightController.text),
        caloriesKcal: NumberUtils.toDouble(_caloriesController.text),
        proteinG: NumberUtils.toDouble(_proteinController.text),
        carbsG: NumberUtils.toDouble(_carbsController.text),
        fatG: NumberUtils.toDouble(_fatController.text),
        confidence: _confidenceController.text.trim().isEmpty
            ? null
            : NumberUtils.toDouble(_confidenceController.text),
        estimationNotes: _notesController.text.trim(),
        source: _source,
        items: _items.map((item) => item.toFoodItem()).toList(),
      );

      await context.read<AppServices>().foodRepository.updateFoodRecord(
        updated,
      );

      if (!mounted) {
        return;
      }

      context.read<RefreshNotifier>().markDataChanged();
      context.refreshDailySummaryCacheForDates(<String>{_originalDate, _date});
      messenger.showSnackBar(
        SnackBar(content: Text(strings.foodRecordUpdated)),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(strings.failedToSaveFoodRecord(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.foodDetailTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    FoodDateTile(date: _date, onChange: _pickDate),
                    const SizedBox(height: 8),
                    FoodFormField(
                      controller: _mealNameController,
                      labelText: strings.foodMealNameLabel,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Please enter meal name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FoodFormField(
                            controller: _weightController,
                            labelText: strings.foodTotalWeightLabel,
                            suffixText: strings.unitGram,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FoodFormField(
                            controller: _caloriesController,
                            labelText: strings.foodCaloriesLabel,
                            suffixText: strings.unitKcal,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FoodFormField(
                            controller: _proteinController,
                            labelText: strings.foodProteinLabel,
                            suffixText: strings.unitGram,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FoodFormField(
                            controller: _carbsController,
                            labelText: strings.foodCarbsLabel,
                            suffixText: strings.unitGram,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FoodFormField(
                            controller: _fatController,
                            labelText: strings.foodFatLabel,
                            suffixText: strings.unitGram,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FoodFormField(
                      controller: _confidenceController,
                      labelText: strings.foodConfidenceLabel,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FoodFormField(
                      controller: _notesController,
                      labelText: strings.foodEstimationNotesLabel,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(label: Text('source: $_source')),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Items',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_items.isEmpty)
                      Text(strings.noFoodItemRows)
                    else
                      ..._items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: <Widget>[
                                FoodFormField(
                                  initialValue: item.name,
                                  labelText: strings.foodItemNameLabel(
                                    index + 1,
                                  ),
                                  onChanged: (value) => item.name = value,
                                ),
                                const SizedBox(height: 8),
                                FoodFormField(
                                  initialValue: item.estimatedWeightG,
                                  labelText: strings.foodTotalWeightLabel,
                                  suffixText: strings.unitGram,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (value) =>
                                      item.estimatedWeightG = value,
                                ),
                                const SizedBox(height: 8),
                                FoodFormField(
                                  initialValue: item.caloriesKcal,
                                  labelText: strings.foodCaloriesLabel,
                                  suffixText: strings.unitKcal,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (value) =>
                                      item.caloriesKcal = value,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: FoodFormField(
                                        initialValue: item.proteinG,
                                        labelText: strings.foodProteinLabel,
                                        suffixText: strings.unitGram,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (value) =>
                                            item.proteinG = value,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FoodFormField(
                                        initialValue: item.carbsG,
                                        labelText: strings.foodCarbsLabel,
                                        suffixText: strings.unitGram,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (value) =>
                                            item.carbsG = value,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FoodFormField(
                                        initialValue: item.fatG,
                                        labelText: strings.foodFatLabel,
                                        suffixText: strings.unitGram,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (value) => item.fatG = value,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                FoodFormField(
                                  initialValue: item.notes,
                                  labelText: strings.foodNotesLabel,
                                  onChanged: (value) => item.notes = value,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FoodSaveButton(
            saving: _saving,
            label: strings.save,
            onPressed: _save,
          ),
        ),
      ),
    );
  }
}
