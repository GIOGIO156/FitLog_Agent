import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/fitlog_bottom_nav_bar.dart';
import '../../core/widgets/fitlog_ui.dart';
import '../../core/widgets/glass_panel.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/food_record.dart';
import 'add_food_page.dart';
import 'food_detail_page.dart';

class FoodLogPage extends StatefulWidget {
  const FoodLogPage({super.key});

  @override
  State<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends State<FoodLogPage> {
  Future<List<FoodRecord>> _loadRecords(BuildContext context, String day) {
    return context.read<AppServices>().foodRepository.getFoodRecordsByDate(day);
  }

  Future<void> _openAddFood(BuildContext context, String initialDate) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddFoodPage(initialDate: initialDate),
      ),
    );

    if (saved == true && context.mounted) {
      context.read<RefreshNotifier>().markDataChanged();
    }
  }

  Future<void> _openFoodDetail(BuildContext context, int recordId) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FoodDetailPage(recordId: recordId),
      ),
    );

    if (updated == true && context.mounted) {
      context.read<RefreshNotifier>().markDataChanged();
    }
  }

  Future<void> _deleteRecord(BuildContext context, FoodRecord record) async {
    final services = context.read<AppServices>();
    final refreshNotifier = context.read<RefreshNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(strings.deleteRecord),
              content: Text(
                strings.deleteFoodConfirm(record.mealName, record.date),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.cancel),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(strings.delete),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await services.foodRepository.deleteFoodRecord(record.id!);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(strings.failedToDeleteFood(error))),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    refreshNotifier.markDataChanged();
    messenger.showSnackBar(SnackBar(content: Text(strings.foodDeleted)));
  }

  Future<void> _copyRecord(
    BuildContext context,
    FoodRecord record,
    String initialDate,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateUtilsX.parseDay(initialDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !context.mounted) {
      return;
    }

    final targetDate = DateUtilsX.formatDate(pickedDate);
    final services = context.read<AppServices>();
    final refreshNotifier = context.read<RefreshNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.stringsRead;

    final copiedRecord = FoodRecord(
      date: targetDate,
      mealName: record.mealName,
      totalWeightG: record.totalWeightG,
      caloriesKcal: record.caloriesKcal,
      proteinG: record.proteinG,
      carbsG: record.carbsG,
      fatG: record.fatG,
      confidence: record.confidence,
      estimationNotes: record.estimationNotes,
      source: record.source,
      items: record.items
          .map(
            (item) => FoodItem(
              name: item.name,
              estimatedWeightG: item.estimatedWeightG,
              caloriesKcal: item.caloriesKcal,
              proteinG: item.proteinG,
              carbsG: item.carbsG,
              fatG: item.fatG,
              notes: item.notes,
            ),
          )
          .toList(),
    );

    try {
      await services.foodRepository.insertFoodRecord(copiedRecord);
      if (!context.mounted) {
        return;
      }
      refreshNotifier.markDataChanged();
      messenger.showSnackBar(
        SnackBar(
          content: Text(strings.foodCopied(record.mealName, targetDate)),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(strings.failedToCopyFood(error))),
      );
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    SelectedDateNotifier selectedDateNotifier,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateUtilsX.parseDay(selectedDateNotifier.selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null && context.mounted) {
      selectedDateNotifier.setDate(DateUtilsX.formatDate(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final fitTheme = context.fitLogTheme;

    return SafeArea(
      bottom: false,
      child: Consumer2<RefreshNotifier, SelectedDateNotifier>(
        builder: (context, refresh, selectedDateNotifier, _) {
          refresh.version;
          final selectedDate = selectedDateNotifier.selectedDate;

          return Column(
            children: <Widget>[
              FitLogPageHeader(
                title: strings.foodLogTitle,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              ),
              GlassPanel(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(16),
                child: FitLogDateStrip(
                  selectedDate: selectedDate,
                  onSelect: selectedDateNotifier.setDate,
                  onOpenPicker: () => _pickDate(context, selectedDateNotifier),
                ),
              ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: FutureBuilder<List<FoodRecord>>(
                        future: _loadRecords(context, selectedDate),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  strings.failedToLoadFood(snapshot.error!),
                                ),
                              ),
                            );
                          }

                          final records = snapshot.data ?? <FoodRecord>[];
                          if (records.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  strings.noFoodRecords,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: EdgeInsets.only(
                              bottom:
                                  FitLogBottomNavBar.floatingControlScreenScrollBottomPaddingFor(
                                    context,
                                    contentGap: 16,
                                  ),
                            ),
                            itemCount: records.length + 1,
                            itemBuilder: (context, index) {
                              if (index == records.length) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    20,
                                  ),
                                  child: Text(
                                    strings.estimateNotice,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: fitTheme.mutedText,
                                          height: 1.4,
                                        ),
                                  ),
                                );
                              }

                              final record = records[index];
                              return GlassPanel(
                                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                padding: const EdgeInsets.all(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () =>
                                      _openFoodDetail(context, record.id!),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              record.mealName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: fitTheme.primarySoft,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              strings.sourceLabel(
                                                record.source,
                                              ),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: fitTheme.primaryDeep,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _buildSubtitle(record),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: fitTheme.textSecondary,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: <Widget>[
                                          _FoodMetaChip(
                                            label:
                                                '${record.caloriesKcal.toStringAsFixed(0)} kcal',
                                          ),
                                          const SizedBox(width: 8),
                                          _FoodMetaChip(
                                            label:
                                                'P ${record.proteinG.toStringAsFixed(0)} · C ${record.carbsG.toStringAsFixed(0)} · F ${record.fatG.toStringAsFixed(0)}',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: <Widget>[
                                          Text(
                                            DateUtilsX.formatReadable(
                                              record.date,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: fitTheme.mutedText,
                                                ),
                                          ),
                                          const Spacer(),
                                          FitLogActionIconButton(
                                            icon: Icons.copy_all_outlined,
                                            tooltip: strings.copy,
                                            onPressed: () => _copyRecord(
                                              context,
                                              record,
                                              selectedDate,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          FitLogActionIconButton(
                                            icon: Icons.delete_outline_rounded,
                                            tooltip: strings.delete,
                                            onPressed: () =>
                                                _deleteRecord(context, record),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          FitLogBottomNavBar.floatingControlScreenBottomPaddingFor(
                            context,
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: FitLogBottomNavBar.floatingControlHeight,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _openAddFood(context, selectedDate),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(strings.addFood),
                            style: FilledButton.styleFrom(
                              backgroundColor: fitTheme.primary,
                              foregroundColor: fitTheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _buildSubtitle(FoodRecord record) {
    if (record.items.isEmpty) {
      return '${record.totalWeightG.toStringAsFixed(0)} g';
    }
    return record.items.take(3).map((item) => item.name).join(', ');
  }
}

class _FoodMetaChip extends StatelessWidget {
  const _FoodMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fitTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fitTheme.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: fitTheme.textSecondary,
        ),
      ),
    );
  }
}
