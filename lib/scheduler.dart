// Handle scheduled tasks, like fetching DepartureVision and notifying the user 
// when a watched train is posted.

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'config.dart';
import 'datastore.dart';
import 'model.dart';
import 'notifications.dart';

class ChooChooScheduler {
  static ChooChooNotifications _notifications;

  static appInitialize() async {
     await AndroidAlarmManager.initialize();
  }

  static stateInitialize(ChooChooNotifications notifications) {
    _notifications = notifications;
  }

  // Register the callbacks for the given WatchedStop.
  static registerWatchedStop(WatchedStop stop) async {
    var delay = stop.stop.nextScheduledDeparture().difference(DateTime.now());
    if (delay > Config.startCheckingDV) {
      delay = delay - Config.startCheckingDV;
    } else {
      delay = new Duration(seconds: 1);
    }
    AndroidAlarmManager.oneShot(delay, stop.stop.id(), () => _checkStop(stop));
    print('Registered timer in $delay (${DateTime.now().add(delay)}) for $stop');
  }

  static _checkStop(WatchedStop stop) async {
    print('_checkStop($stop)');
    await Datastore.refreshStatuses(stop.stop.departureStation);
    var status = Datastore.currentStatusForStop(stop.stop);

    // This shouldn't be null since we just refreshed the statuses, and we should only
    // call _checkStop when there's a train upcoming.
    // TODO(ahogue): Do we need to clear old statuses for the station in the 
    // datastore when we refresh?
    if (null != status) {
      _notifications.trainStatusNotification(status);
      if (status.calculatedDepartureTime.isAfter(DateTime.now())) {
        AndroidAlarmManager.oneShot(Config.recheckDV, stop.stop.id(), _checkStop(stop));
      }
    }
  }
}