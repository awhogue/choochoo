// Handle scheduled tasks, like fetching DepartureVision and notifying the user 
// when a watched train is posted.

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'config.dart';
import 'datastore.dart';
import 'model.dart';
import 'notifications.dart';

class ChooChooScheduler {
  static ChooChooNotifications _notifications = ChooChooNotifications();

  static appInitialize() async {
    print('ChooChooScheduler.appInitialize()');
    await AndroidAlarmManager.initialize();
  }

  static stateInitialize(ChooChooNotifications notifications) {
    _notifications = notifications;
  }

  // Schedule the next time to wake up and check train status based on the current
  // set of WatchedStops.
  static updateScheduledNotifications() async {
    WatchedStop ws = await Datastore.nextWatchedDeparture();
    if (null == ws) {
      print('updateScheduledNotifications(): no WatchedStops registered');
      return;
    }
    print('updateScheduledNotifications($ws)');
    print('nextScheduledDeparture: ${ws.nextScheduledDeparture()}');
    print('now:                    ${DateTime.now()}');
    var delay = ws.nextScheduledDeparture().difference(DateTime.now());
    print('Initial delay: $delay');
    if (delay > Config.startCheckingDV) {
      delay = delay - Config.startCheckingDV;
      print('Shortened delay: $delay');
    } else {
      delay = new Duration(seconds: 5);
      print('Already inside time to start checking DV. Delay: $delay');
    }

    // TODO: unregister any existing callbacks we've already set up.
    await _scheduleOneShot(delay, ws.stop.id());
  }

  static void _checkWatchedStops() async {
    WatchedStop ws = await Datastore.nextWatchedDeparture();
    print('_checkWatchedStops(): next departure: $ws');
    if (null == ws) return;

    await Datastore.refreshStatuses(ws.stop.departureStation);
    var status = Datastore.currentStatusForStop(ws.stop);

    // This shouldn't be null since we just refreshed the statuses, and we should only
    // call _checkStop when there's a train upcoming.
    // TODO(ahogue): Do we need to clear old statuses for the station in the 
    // datastore when we refresh?
    if (null != status) {
      _notifications.trainStatusNotification(status);
      if (status.calculatedDepartureTime.isAfter(DateTime.now())) {
        await _scheduleOneShot(Config.recheckDV, ws.stop.id());
      }
    }
  }

  static _scheduleOneShot(Duration delay, int id) {
    print('Registered oneShot in $delay (${DateTime.now().add(delay)})');
    return AndroidAlarmManager.oneShot(
      delay, 
      id, 
      _checkWatchedStops,
      exact: true,
      wakeup: true
    );
  }
}