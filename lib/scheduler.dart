// Handle scheduled tasks, like fetching DepartureVision and notifying the user 
// when a watched train is posted.

import 'package:flutter/services.dart';
import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'datastore.dart';
import 'model.dart';
import 'notifications.dart';

class ChooChooScheduler {
  static ChooChooNotifications _notifications;
  static AssetBundle _bundle;

  static appInitialize() async {
     await AndroidAlarmManager.initialize();
  }

  static stateInitialize(ChooChooNotifications notifications,
                         AssetBundle bundle) {
    _notifications = notifications;
    _bundle = bundle;
  }

  // How long before a scehduled departure do we start checking DepartureVision?
  static final Duration _startCheckingDV = Duration(minutes: 30);
  // How long to wait in between checking DepartureVision while monitoring a train?
  static final Duration _recheckDV = Duration(minutes: 5);

  // Register the callbacks for the given WatchedStop.
  static registerWatchedStop(WatchedStop stop) async {
    var delay = stop.stop.nextScheduledDeparture().difference(DateTime.now());
    if (delay > _startCheckingDV) {
      delay = delay - _startCheckingDV;
    }
    AndroidAlarmManager.oneShot(delay, stop.stop.id(), () => _checkStop(stop));
    print('Registered timer in $delay (${DateTime.now().add(delay)}) for $stop');
  }

  static _checkStop(WatchedStop stop) async {
    await Datastore.refreshStatuses(stop.stop.departureStation, _bundle);
    var status = Datastore.currentStatusForStop(stop.stop);

    // This shouldn't be null since we just refreshed the statuses, and we should only
    // call _checkStop when there's a train upcoming.
    // TODO(ahogue): Do we need to clear old statuses for the station in the 
    // datastore when we refresh?
    if (null != status) {
      _notifications.trainStatusNotification(status);
      if (status.calculatedDepartureTime.isAfter(DateTime.now())) {
        AndroidAlarmManager.oneShot(_recheckDV, stop.stop.id(), _checkStop(stop));
      }
    }
  }
}