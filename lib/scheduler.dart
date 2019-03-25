// Handle scheduled tasks, like fetching DepartureVision and notifying the user 
// when a watched train is posted.

import 'dart:isolate';
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

  static _nextDeparture() async {
    print('_nextDeparture() isolate ${Isolate.current.hashCode}');

    await Datastore.loadWatchedStops();
    List<WatchedStop> watchedStops = Datastore.watchedStops.values.toList();
    print('_nextDeparture found ${watchedStops.length} stops');
    if (watchedStops.isEmpty) return null;
    watchedStops.sort((a, b) => a.stop.nextScheduledDeparture().compareTo(b.stop.nextScheduledDeparture()));
    return watchedStops[0];
  }

  // Schedule the next time to wake up and check train status based on the current
  // set of WatchedStops.
  static updateScheduledNotifications() async {
    WatchedStop ws = await _nextDeparture();
    if (null == ws) {
      print('updateScheduledNotifications(): no WatchedStops registered');
      return;
    }
    print('updateScheduledNotifications($ws)');
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
    // TODO: unregister any existing callbacks we've already set up.
    bool result = await AndroidAlarmManager.oneShot(
      delay, 
      ws.stop.id(), 
      _checkWatchedStops,
      exact: true,
      wakeup: true
    );
    print('Registered timer in $delay (${DateTime.now().add(delay)}) for $ws');
    print('result: $result');
  }

  static void _checkWatchedStops() async {
    Config.forceScheduledNotification = true;

    print('_checkWatchedStops()');
    WatchedStop ws = await _nextDeparture();
    print('next departure: $ws');
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
        AndroidAlarmManager.oneShot(Config.recheckDV, ws.stop.id(), _checkWatchedStops);
      }
    }
  }
}