import 'package:intl/intl.dart';

class DateTimeHelper {
  static String formatToReadable(DateTime dateTime) {
    final formatted = DateFormat('EEEE, d MMM yyyy').format(dateTime);
    return formatted.toLowerCase().replaceFirst(
      formatted[0].toLowerCase(),
      formatted[0], // Keep first letter capital (Tuesday)
    );
  }

  static String getTimeOfDay() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Morning";
    } else if (hour < 17) {
      return "Afternoon";
    } else {
      return "Evening";
    }
  }

  String formatCustomDateTime(DateTime dateTime) {
    final now = DateTime.now();

    final bool isToday =
        dateTime.year == now.year &&
            dateTime.month == now.month &&
            dateTime.day == now.day;

    final timeFormat = DateFormat('hh:mm a');
    final formattedTime = timeFormat.format(dateTime).toLowerCase();

    if (isToday) {
      return formattedTime; // 07:00 am
    } else {
      final dayFormat = DateFormat('EEE d');
      final formattedDay = dayFormat.format(dateTime); // Thu 2
      return '$formattedDay, $formattedTime';
    }
  }

}
