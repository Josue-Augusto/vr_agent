class CronExpression {
  final List<_CronField> _fields;

  CronExpression(String expression)
    : _fields = _parse(expression);

  bool matches(DateTime dateTime) {
    final minute = _fields[0].matches(dateTime.minute);
    final hour = _fields[1].matches(dateTime.hour);
    final dayOfMonth = _fields[2].matches(dateTime.day);
    final month = _fields[3].matches(dateTime.month);
    final dayOfWeekValue = dateTime.weekday % 7;
    final dayOfWeek = _fields[4].matches(dayOfWeekValue);
    final dayMatches = _fields[2].wildcard || _fields[4].wildcard
        ? dayOfMonth && dayOfWeek
        : dayOfMonth || dayOfWeek;
    return minute && hour && month && dayMatches;
  }

  static List<_CronField> _parse(String expression) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) {
      throw FormatException('A expressão cron deve conter exatamente cinco campos: $expression');
    }
    return [
      _CronField.parse(parts[0], 0, 59),
      _CronField.parse(parts[1], 0, 23),
      _CronField.parse(parts[2], 1, 31),
      _CronField.parse(parts[3], 1, 12, aliases: _months),
      _CronField.parse(
        parts[4],
        0,
        7,
        sundaySeven: true,
        aliases: _weekdays,
      ),
    ];
  }

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  static const _weekdays = {
    'sun': 0,
    'mon': 1,
    'tue': 2,
    'wed': 3,
    'thu': 4,
    'fri': 5,
    'sat': 6,
  };
}

class _CronField {
  final Set<int> values;
  final bool wildcard;

  const _CronField(this.values, this.wildcard);

  factory _CronField.parse(
    String expression,
    int minimum,
    int maximum, {
    bool sundaySeven = false,
    Map<String, int> aliases = const {},
  }) {
    final values = <int>{};
    for (final item in expression.split(',')) {
      final stepParts = item.split('/');
      if (stepParts.length > 2) {
        throw FormatException('Campo cron inválido: $expression');
      }
      final step = stepParts.length == 2 ? int.tryParse(stepParts[1]) : 1;
      if (step == null || step <= 0) {
        throw FormatException('Passo cron inválido: $expression');
      }
      final range = stepParts.first;
      int parseValue(String value) =>
          aliases[value.toLowerCase()] ?? int.tryParse(value) ?? -1;
      late final int start;
      late final int end;
      if (range == '*') {
        start = minimum;
        end = maximum;
      } else if (range.contains('-')) {
        final bounds = range.split('-');
        if (bounds.length != 2) {
          throw FormatException('Intervalo cron inválido: $expression');
        }
        start = parseValue(bounds[0]);
        end = parseValue(bounds[1]);
      } else {
        start = parseValue(range);
        end = stepParts.length == 2 ? maximum : start;
      }
      if (start < minimum || end > maximum || start > end) {
        throw FormatException('Valor fora do intervalo cron: $expression');
      }
      for (var value = start; value <= end; value += step) {
        values.add(sundaySeven && value == 7 ? 0 : value);
      }
    }
    return _CronField(values, expression.startsWith('*'));
  }

  bool matches(int value) => values.contains(value);
}
