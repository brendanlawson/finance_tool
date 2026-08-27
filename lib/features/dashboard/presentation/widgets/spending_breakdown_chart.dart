import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../categories/domain/category_entity.dart';
import '../../domain/monthly_report.dart';

// A plain grey scale rather than a curated brand palette — distinguishable
// slice-to-slice without reading as "designed."
const _paletteFallback = [
  Color(0xFF37474F),
  Color(0xFF546E7A),
  Color(0xFF78909C),
  Color(0xFF90A4AE),
  Color(0xFFB0BEC5),
  Color(0xFFCFD8DC),
];

class SpendingBreakdownChart extends StatelessWidget {
  const SpendingBreakdownChart({
    super.key,
    required this.entries,
    required this.categoriesById,
  });

  final List<CategoryBreakdownEntry> entries;
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spending breakdown', style: theme.textTheme.labelLarge),
              const SizedBox(height: 12),
              Text('No expenses recorded this month yet.', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    // Group the long tail into "Other" so the chart stays readable.
    const maxSlices = 5;
    final top = entries.take(maxSlices).toList();
    final rest = entries.skip(maxSlices);
    final total = entries.fold<int>(0, (sum, e) => sum + e.total.minorUnits);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending breakdown', style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: [
                          for (var i = 0; i < top.length; i++)
                            PieChartSectionData(
                              value: top[i].total.minorUnits.toDouble(),
                              color: _paletteFallback[i % _paletteFallback.length],
                              title: '',
                              radius: 28,
                            ),
                          if (rest.isNotEmpty)
                            PieChartSectionData(
                              value: rest.fold<int>(0, (s, e) => s + e.total.minorUnits).toDouble(),
                              color: theme.colorScheme.outlineVariant,
                              title: '',
                              radius: 28,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ListView(
                      children: [
                        for (var i = 0; i < top.length; i++)
                          _LegendRow(
                            color: _paletteFallback[i % _paletteFallback.length],
                            label: _labelFor(top[i].categoryId),
                            percent: total == 0 ? 0 : top[i].total.minorUnits / total,
                          ),
                        if (rest.isNotEmpty)
                          _LegendRow(
                            color: theme.colorScheme.outlineVariant,
                            label: 'Other',
                            percent: total == 0
                                ? 0
                                : rest.fold<int>(0, (s, e) => s + e.total.minorUnits) / total,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(String? categoryId) {
    if (categoryId == null) return 'Uncategorized';
    return categoriesById[categoryId]?.name ?? 'Uncategorized';
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.percent});

  final Color color;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          Text('${(percent * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}
