import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:formcoach/data/repositories/progress_repository.dart';
import 'package:formcoach/domain/weight_unit.dart';
import 'package:formcoach/features/progress/progress_formatting.dart';
import 'package:formcoach/features/progress/progress_stats.dart';

/// Bars showing the training volume of each recent week, in [unit].
class VolumeChart extends StatelessWidget {
  const VolumeChart({required this.weeks, required this.unit, super.key});

  final List<WeeklyVolume> weeks;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = [for (final week in weeks) unit.fromKg(week.volumeKg)];
    final maxValue = values.fold<double>(0, (a, b) => a > b ? a : b);
    return Semantics(
      label: 'Weekly training volume in ${unit.label}',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxValue == 0 ? 1 : maxValue * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      '${rod.toY.round()} ${unit.label}',
                      TextStyle(color: scheme.onInverseSurface),
                    ),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= weeks.length || index.isOdd) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        shortDate(weeks[index].weekStart),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      color: scheme.primary,
                      width: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line of the Form Coach's scores (0 to 100) for one exercise over time.
class FormScoreChart extends StatelessWidget {
  const FormScoreChart({required this.points, super.key});

  /// The scores of one exercise, oldest first.
  final List<CoachScorePoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Form score over time, latest ${points.last.score.round()}',
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            minX: 0,
            maxX: (points.length - 1).clamp(1, 1 << 30).toDouble(),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 25,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.round()}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].score),
                ],
                isCurved: false,
                color: scheme.primary,
                barWidth: 3,
                dotData: const FlDotData(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
