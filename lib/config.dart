// Configuration and other constants and convenience functions for setting them 
// for various scenarios (dev, testing, production).
// 
// Most configuration variables are set to a "reasonable" default for production use.
// These may be overridden by calling one of the convenience functions, e.g. to set up
// the app for testing.
// 
// Typical usage:
//   Config.setAssetBundle(DefaultAssetBundle.of(context));
//   // optionally set config bundles for particular use cases.
//   Config.setOfflineDebugCOnfig();
//   // optionally set specific variables for testing.
//   Config.forceScheduledNotification = true;

import 'package:flutter/services.dart';
import 'datastore.dart';
import 'model.dart';

enum Mode {
  PROD,
  DEBUG,
  TEST,
}

class Config {
  // What mode are we running in?
  static Mode mode = Mode.PROD;
  static bool debug() => (mode == Mode.DEBUG);

  ///////////// Caching /////////////
  // Should we read from the cache by default for calls to refreshStatuses?
  static bool readCache = true;
  // Should we write to the cache by default for calls to refreshStatuses?
  static bool writeCache = true;
  // What is the maximum allowable age for the cache files before we re-fetch?
  // (in minutes)
  static Duration maxCacheAge = Duration(minutes: 5);
  // Should we create a cache at startup using the cached data we use for unit tests?
  static bool primeCacheFromTestData = false;

  ///////////// DepartureVision /////////////
  // How long before a scheduled departure should we start checking DV?
  static Duration startCheckingDV = Duration(minutes: 30);
  // How long to wait in between checking DepartureVision while monitoring a train?
  static Duration recheckDV = Duration(minutes: 5);

  ///////////// Notifications /////////////
  // Should we force a notification on startup?
  static bool forceNotificationOnStartup = false;
  // Should we force a scheduled notification on startup?
  static bool forceScheduledNotification = false;

  ///////////// Assets /////////////

  // The asset bundle we're using for this instantiation.
  static AssetBundle bundle;
  static setBundle(AssetBundle b) => bundle = b;

  ///////////// Testing /////////////

  // A few datastore constants that are useful for testing.
  static final String _hhk = 'HOHOKUS';  // Ho-Ho-Kus station name.
  static final String _hob = 'HOBOKEN';  // Hoboken station name.
  static hhkStation() => Datastore.stationByStationName[_hhk];  // Assumes data has been loaded.
  static hobStation() => Datastore.stationByStationName[_hob];  // Assumes data has been loaded.
  static final int id803am = 1162;      // tripId for the 8:03am from Ho-Ho-Kus to Hoboken.

  // Fake a WatchedStop and Status for testing.
  static WatchedStop setupFakes(DateTime departureTime, DateTime calculatedDepartureTime, TrainState state) {    
    Train train = Train('999999', Config.hobStation(), 999999);
    Stop stop = Stop(train, Config.hhkStation(), departureTime, Stop.everyday);
    WatchedStop watchedStop = WatchedStop(stop, [DateTime.now().weekday]);
    TrainStatus status = TrainStatus(stop, "FAKE STOP", state, calculatedDepartureTime, DateTime.now());
    Datastore.addTrain(train);
    Datastore.addStop(stop);
    Datastore.addWatchedStop(watchedStop);
    Datastore.addStatus(status);
    return watchedStop;
  }

  // Configuration for unit tests.
  static setUnitTestConfig() {
    mode = Mode.TEST;
    writeCache = false;
    maxCacheAge = Duration(days: 10000);
  }

  // Settings to not have to use the network (e.g. for offline or to just ignore 
  // the live call to DepartureVision);
  static setOfflineDebugConfig() {
    mode = Mode.DEBUG;
    readCache = true;
    writeCache = false;
    maxCacheAge = Duration(days: 100000);
    primeCacheFromTestData = true;
  }

  static setForceScheduledNotification() {
    forceNotificationOnStartup = true;
    startCheckingDV = Duration(seconds: 1);
  }

  static String configString() {
    return [
      'CONFIG:', 
      'mode:   $mode', 
      'Cache:  read: $readCache, write: $writeCache, maxAge: $maxCacheAge, testData: $primeCacheFromTestData',
      'DV:     start: $startCheckingDV, recheck interval: $recheckDV',
      'Notifs: forceOnStartup: $forceNotificationOnStartup, forceScheduled: $forceScheduledNotification',
    ].join('\n  ');
  }
}