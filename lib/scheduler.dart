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
    print('ChooChooScheduler.appInitialize()');
    await AndroidAlarmManager.initialize();
  }

  static stateInitialize(ChooChooNotifications notifications) {
    _notifications = notifications;
  }

  // Register the callbacks for the given WatchedStop.
  static registerWatchedStop(WatchedStop ws) async {
    print('registerWatchedStop($ws)');
    print('ws.stop.nextScheduledDeparture: ${ws.stop.nextScheduledDeparture()}');
    print('now:                            ${DateTime.now()}');
    var delay = ws.stop.nextScheduledDeparture().difference(DateTime.now());
    print('Initial delay: $delay');
    if (delay > Config.startCheckingDV) {
      delay = delay - Config.startCheckingDV;
      print('Shortened delay: $delay');
    } else {
      delay = new Duration(seconds: 5);
      print('Already inside time to start checking DV. Delay: $delay');
    }

    print('oneShot($delay)');
    await AndroidAlarmManager.oneShot(delay, ws.stop.id(), () => _checkStop(ws));
    print('Registered timer in $delay (${DateTime.now().add(delay)}) for $ws');
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