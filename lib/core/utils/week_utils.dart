DateTime startOfWeekMonday(DateTime date) {
  // Monday = 1 ... Sunday = 7
  final diff = date.weekday - 1;
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: diff));
}

List<DateTime> weekDaysMonSun(DateTime date) {
  final start = startOfWeekMonday(date);
  return List.generate(7, (i) => start.add(Duration(days: i)));
}
