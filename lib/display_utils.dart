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
        var calculatedDepartureDiff = status.calculatedDepartureTime.difference(status.stop.scheduledDepartureTime).inMinutes;
        return '${_statusMinutesStr(calculatedDepartureDiff)}, now at ${timeDisplayFormat.format(status.calculatedDepartureTime)}';
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
          'now at ${timeDisplayFormat.format(status.calculatedDepartureTime)} ' +
          '(was ${timeDisplayFormat.format(status.stop.scheduledDepartureTime)})';
      case TrainState.Canceled:
        return '(was ${timeDisplayFormat.format(status.stop.scheduledDepartureTime)})';
      case TrainState.NotPosted:
      case TrainState.OnTime:
      case TrainState.AllAboard:
      case TrainState.Unknown:
      default:
        return 'scheduled at ${timeDisplayFormat.format(status.stop.scheduledDepartureTime)}';
    }
  }
}