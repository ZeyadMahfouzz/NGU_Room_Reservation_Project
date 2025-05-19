const Map<String, int> dayToWeekday = {
  "sunday": DateTime.sunday,
  "monday": DateTime.monday,
  "tuesday": DateTime.tuesday,
  "wednesday": DateTime.wednesday,
  "thursday": DateTime.thursday,
  "friday": DateTime.friday,
  "saturday": DateTime.saturday,
};

List<DateTime> getDatesForWeekday(DateTime start, DateTime end, int weekday) {
  List<DateTime> dates = [];
  DateTime current = start;

  while (current.weekday != weekday) {
    current = current.add(const Duration(days: 1));
  }

  while (!current.isAfter(end)) {
    dates.add(current);
    current = current.add(const Duration(days: 7));
  }

  return dates;
}
