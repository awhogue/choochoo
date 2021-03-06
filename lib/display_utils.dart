// Utilities for displaying and formatting train information.

import 'package:intl/intl.dart';
import 'model.dart';

class DisplayUtils {
  static final DateFormat timeDisplayFormat = new DateFormat.jm();

  static String _statusMinutesStr(int minutes) {
    if (minutes == 0) return 'On time';
    var minStr = (minutes.abs() == 1) ? 'minute' : 'minutes';
    var lateStr = (minutes > 0) ? 'late' : 'early!';
    return '$minutes $minStr $lateStr';
  }

  // Simple display string for a train's status.
  static String shortStatus(TrainStatus status) {
    switch (status.state) {
      case TrainState.NotPosted: 
        return 'Not yet posted';
      case TrainState.OnTime:
        return 'On time';
      case TrainState.Late:
      case TrainState.Early: {        
        return _statusMinutesStr(status.getMinutesLateEarly());
      }
      case TrainState.AllAboard:
        return 'ALL ABOARD!';
      case TrainState.Canceled: 
        return 'CANCELED';
      case TrainState.Unknown:
      default: return status.rawStatus;
    }
  }

  // A time string to display to the user, including the originally scheduled and
  // currently scheduled time for the train, if it's running late.
  static String timeStatus(TrainStatus status) {
    switch (status.state) {
      case TrainState.Late:
      case TrainState.Early:
        return 
          'Now at ${timeString(status.getTodaysDepartureTime())}';
      case TrainState.OnTime:
        return 'In ${status.getMinutesUntilDeparture()} min';
      case TrainState.NotPosted:
        return 'Scheduled at ${status.departureTime()}';
      case TrainState.Canceled:
      case TrainState.AllAboard:
      case TrainState.Unknown:
      default:
        return '';
    }
  }

  static String timeString(DateTime time) {
    return timeDisplayFormat.format(time);
  }
}