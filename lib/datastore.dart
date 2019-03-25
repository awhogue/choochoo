// Datastore for data loaded from disk, DepartureVision, or user preferences.
//
// Call Datastore.loadDataFiles() once when the app is initialized to load the 
// base data for trains and stops. Then call Datastore.refreshStatuses() to 
// load live data from DepartureVision on demand.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart';
import 'package:html/dom.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'file_utils.dart';
import 'model.dart';
import 'scheduler.dart';

class Datastore {
  /* **************************************************************** */
  // "Static" data about stations, trains, and stops, loaded from 
  // NJ Transit data files 
  /* **************************************************************** */
  static final Map<String, Station> stationByStationName = new Map();
  static final Map<int, Station> stationByStopId = new Map();

  static final Map<int, Train> trainByTripId = new Map();
  static final Map<String, int> trainNoToTripId = new Map();

  // Index of stops on stop.id(), loaded from the data files.
  static final Map<int, Stop> _stopByTripId = Map();

  static addStation(Station station) {
    stationByStationName[station.stationName] = station;
    stationByStopId[station.stopId] = station;
  }

  static addTrain(Train train) {
    trainByTripId[train.tripId] = train;
    trainNoToTripId[train.trainNo] = train.tripId;
  }

  static addStop(Stop stop) {
    _stopByTripId[stop.id()] = stop;
  }

  static Train trainFromTrainNo(String trainNo) {
    if (!trainNoToTripId.containsKey(trainNo)) {
      print('Unknmown trainNo: $trainNo');
      return null;
    }
    return trainByTripId[trainNoToTripId[trainNo]];
  }
  
  static Stop stopByTripId(int tripId, int depatureStationId) {
    return _stopByTripId[Stop.idFromRaw(tripId, depatureStationId)];
  }

  static Stop stopByTrainNo(String trainNo, int departureStationId) {
    return stopByTripId(trainNoToTripId[trainNo], departureStationId);
  }

  // *******************************************************************
  // "Live" data about train status from DepartureVIsion, loaded from 
  // the DepartureVision site.
  // *******************************************************************

  // The current set of statuses, keyed on Station.stationName. Each value
  // is a map from Stop.id() to a status.
  static final Map<String, Map<int, TrainStatus>> statuses = Map();

  static addStatus(TrainStatus status) {
    statuses.putIfAbsent(status.stop.departureStation.stationName, () => Map());
    statuses[status.stop.departureStation.stationName][status.stop.id()] = status;
  }
  
  // The list of statuses in chronological order for the given station.
  static List<TrainStatus> statusesInOrder(Station station) {
    if (!statuses.containsKey(station.stationName)) {
      print('No statuses for ${station.stationName}, did you call refreshStatuses?');
      return [];
    }
    var statusList = statuses[station.stationName].values.toList();
    statusList.sort((a, b) => a.getDepartureTime().compareTo(b.getDepartureTime()));
    return statusList;
  }

  static List<TrainStatus> allStatuses() {
    List<TrainStatus> all = [];
    for (var mp in statuses.values) {
      all.addAll(mp.values.toList());
    }
    return all;
  }

  // Return the current status for the given stop, or null if we don't have one.
  static TrainStatus currentStatusForStop(Stop stop) {
    var stationName = stop.departureStation.stationName;
    if (statuses.containsKey(stationName) && 
        statuses[stationName].containsKey(stop.id())) {
      return statuses[stationName][stop.id()];
    }
    return null;
  }

  // *******************************************************************
  // User preferences data, including stops the user wants to be 
  // notified about.
  // *******************************************************************

  // Stops the user is watching, keyed on Stop.id()
  static final Map<int, WatchedStop> watchedStops = Map();

  // *******************************************************************
  // Initialization functions to load data.
  // The main API is:
  //   loadData() – load "static" data from disk.
  //   refreshStatuses() - refresh status from DepartureVision
  //   loadWatchedStops() / addWatchedStop() – load/add a stop the user wants to watch.
  // *******************************************************************
  static bool _dataLoaded = false;
  static Future loadData() async {
    if (_dataLoaded) {
      print('loadData(): already loaded (${stationByStationName.length} stations, ' +
            '${trainByTripId.length} Trains, ${_stopByTripId.length} Stops)');
      return;
    }
    print('Loading datafiles...');
    var start = DateTime.now();
    await _loadStations();
    await _loadTrains();
    await _loadStops();
    
    if (Config.forceScheduledNotification) {
      Config.setupFakes(
        DateTime.now().add(Duration(minutes: 10)),
        DateTime.now().add(Duration(minutes: 15)),
        TrainState.Late);
    }

    var timing = DateTime.now().difference(start).inMilliseconds;
    print('Loaded data files in ${timing}ms.');
    _dataLoaded = true;
  }

  // Refresh the list of statuses for the given station, either directly from
  // the DepartureVision site, or using the cache (if available and fresh). 
  static Future refreshStatuses(Station station) async {
    await loadData();
    print('Refreshing statuses...');
    var start = DateTime.now();
    String html = await _fetchDepartureVision(station);
    await _parseDepartureVision(html, station);

    var timing = DateTime.now().difference(start).inMilliseconds;
    print('Loaded statuses in ${timing}ms.');
  }

  static Future loadWatchedStops() async {
    await _loadPrefs();
    await loadData();
    for (var ws in loadWatchedStopsFromJson(_prefs.getString(_watchedStopsKey) ?? '[]')) {
      print(ws);
      addWatchedStops([ws]);
    }
    print('Loaded ${watchedStops.length} watched stops:');
  }

  static Future addWatchedStops(List<WatchedStop> stops) async {
    for (var watchedStop in stops) {
      if (watchedStops.containsKey(watchedStop.stop.id())) {
        print('Already watching $watchedStop');
        return; 
      }
      print('addWatchedStop($watchedStop)');
      watchedStops[watchedStop.stop.id()] = watchedStop;
    }
    await _saveWatchedStops();
    await ChooChooScheduler.updateScheduledNotifications();
  }

  static Future clearWatchedStops() async {
    print('Clearing watched stops!');
    watchedStops.clear();
    await _saveWatchedStops();
    await ChooChooScheduler.updateScheduledNotifications();
  }

  // *******************************************************************
  // Internal functions.
  // *******************************************************************

  static Future _loadStations() async {
    // TODO: probably want to have some sort of real lock while loading data so we don't
    // have two concurrent processes loading at the same time. Also, just checking for 
    // non-empty probably isn't enough to validate that the data loaded correctly.
    Map<String, String> stationToChar = new Map();
    for (var row in await FileUtils.csvFileToArray('station2char.csv')) {
      stationToChar[row[0]] = row[1].toString().trim();
    }

    for (var row in await FileUtils.csvFileToArray('stops.txt')) {
      if (row[0] == 'stop_id') continue;  // Skip header.
      int stopId = row[0];
      String stationName = row[2];
      addStation(new Station(stationName, stationToChar[stationName], stopId));
    }

    print('Loaded ${stationByStationName.length} stations from stops.txt');
  }

  static RegExp _removeLeadingZeros = new RegExp(r'^0+(?!$)');
  static String _fixTrainNo(String rawTrainNo) {
    return rawTrainNo.replaceFirst(_removeLeadingZeros, '');
  }
  static Future _loadTrains() async {
    // TODO: distinguish by service_id for the current date (weekend vs. weekday). Need to join
    // with the calendar_dates.txt file?
    for (var row in await FileUtils.csvFileToArray('trips.txt')) {
      if (row[0] == 'route_id') continue;  // Skip header.
      int tripId = row[2];
      String trainNo = _fixTrainNo(row[5]);
      addTrain(new Train(trainNo, stationByStationName[row[3]], tripId));
    }
    print('Loaded ${trainByTripId.length} trains');
    return;
  }

  static final DateFormat _hourMinuteSecondsFormat = new DateFormat.Hms();
  static Future _loadStops() async {    
    for (var row in await FileUtils.csvFileToArray('stop_times.txt')) {
      if (row[0] == 'trip_id') continue;  // Skip header.
      var tripId = row[0];
      var departureStationId = row[3];
      Train train = trainByTripId[tripId];
      Stop stop = Stop(
        train, 
        stationByStopId[departureStationId], 
        _hourMinuteSecondsFormat.parse(row[2]),
        Stop.everyday);
      addStop(stop);
    }

    print('Loaded ${_stopByTripId.length} trains from stop_times.txt');    

    return _stopByTripId;
  }

  static bool _isCacheFileFresh(File cacheFile) {
    if (!cacheFile.existsSync()) return false;
    return (DateTime.now().difference(cacheFile.lastModifiedSync()) < Config.maxCacheAge);
  }
  // Try to read the cache file for the given station. Returns null if the 
  // cache file is out of date or nonexistant.
  static Future<String> _tryReadCacheFile(Station station) async {
    File cacheFile = await FileUtils.getCacheFile(station.stationName);
    if (cacheFile.existsSync()) {
      if (_isCacheFileFresh(cacheFile)) {
        print('Cache file $cacheFile is fresh. Using it.');
        String html = cacheFile.readAsStringSync();
        print('Read ${html.length} bytes from $cacheFile');
        return html;
      } else {
        print('Cache file $cacheFile is out of date. Deleting.');
        cacheFile.deleteSync();
        return null;
      }
    } else {
      print('No cached data for ${station.stationName} (looked for $cacheFile)');
      return null;
    }
  }

  // Write the given html to the station's cache file.
  static Future _tryWriteCacheFile(Station station, String html) async {
    File cacheFile = await FileUtils.getCacheFile(station.stationName);
    if (_isCacheFileFresh(cacheFile)) {
      print('Existing cache is still fresh, no need to overwrite.');
      return;
    }
    print('Writing cache for ${station.stationName} to $cacheFile');
    if (cacheFile.existsSync()) {
      print('Deleting old cache file $cacheFile');
      cacheFile.deleteSync();
    }
    cacheFile.writeAsStringSync(html);
    print('Wrote ${html.length} bytes to $cacheFile');
  }

  // Fetch html from the DepartureVision site, or potentially the cache.
  // Disable the cache by setting maxCacheAge to 0 or negative.
  static Future<String> _fetchDepartureVision(Station station) async {
    String cached = (Config.readCache) ? await _tryReadCacheFile(station) : null;
    if (null != cached) {
      return cached;
    }

    HttpClient http = new HttpClient();
    http.userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36';
    http.connectionTimeout = Duration(seconds: 30);
    var uri = Uri.http('dv.njtransit.com', '/mobile/tid-mobile.aspx', {'sid': station.twoLetterCode});
    final maxAttempts = 3;
    final retryWait = 5;
    for (var attempt = 0; attempt < maxAttempts; ++attempt) {
      try {
        print('Fetching $uri, attempt $attempt');
        var request = await http.getUrl(uri);
        var response = await request.close();
        var responseBody = await response.transform(utf8.decoder).join();
        print('Response of ${responseBody.length} bytes:\n${responseBody.substring(0, 200)}...');
        return responseBody;
      } catch (exception) {
        print('EXCEPTION fetching $uri on attempt $attempt:');
        print(exception);
        print('Pausing for $retryWait seconds before retrying...');
        sleep(Duration(seconds: retryWait));
      }
    }
    print('Too many exceptions, giving up.');
    return '';
  }

  static RegExp _updatedTimeRe = new RegExp(r'(\d+:\d+ [AP]M)');
  static final DateFormat _timeDisplayFormat = new DateFormat.jm();
  static DateTime _parseLastUpdatedTime(Document document) {
    // Select all the divs because status messages sometimes pop up with weird formatting.
    var div = document.querySelector('#Label2');
    if (_updatedTimeRe.hasMatch(div.text)) {
      var timeStr = _updatedTimeRe.firstMatch(div.text).group(1);
      return _timeDisplayFormat.parse(timeStr);
    } else {
      print('Could not find last updated time! Defaulting to now.');
      // TODO: deal with time zones 
      // https://stackoverflow.com/questions/26257481/how-to-convert-datetime-into-different-timezones
      // https://pub.dartlang.org/documentation/timezone/latest/
      var now = DateTime.now();
      return new DateTime(now.year, now.month, now.day, now.hour, now.minute);
    }
  }

  static RegExp _inNMinutesRe = new RegExp(r'in (\d+) Min');
  static TrainStatus _parseRawStatus(String rawStatus, DateTime lastUpdated,Stop stop) {
    if (rawStatus.isEmpty) {
      return TrainStatus(stop, rawStatus, TrainState.NotPosted, stop.scheduledDepartureTime, lastUpdated);
    } else if (_inNMinutesRe.hasMatch(rawStatus)) {
      var minutesDelayed = int.parse(_inNMinutesRe.firstMatch(rawStatus).group(1));
      var calculatedDeparture = lastUpdated.add(new Duration(minutes: minutesDelayed));
      var diff = calculatedDeparture.difference(stop.scheduledDepartureTime).inMinutes;
      var state = () {
        // Trains within a minute of departure are considered "on time".
        if (diff <= 1) return TrainState.OnTime;
        else if (diff > 0) return TrainState.Late;
        else return TrainState.Early;
      }();
      return TrainStatus(stop, rawStatus, state, calculatedDeparture, lastUpdated);
    } else if (rawStatus.toUpperCase() == 'ALL ABOARD') {
      return TrainStatus(stop, rawStatus, TrainState.AllAboard, DateTime.now(), lastUpdated);
    } else if (rawStatus.toUpperCase() == 'CANCELLED') {
      return TrainStatus(stop, rawStatus, TrainState.Canceled, stop.scheduledDepartureTime, lastUpdated);
    } else {
      return null;
    }
  }
  // Parse a departurevision HTML file.
  static Future _parseDepartureVision(String html, Station station) async {
    var statusesFound = 0;
    statuses.putIfAbsent(station.stationName, () => Map<int, TrainStatus>());

    var document = parse(html);
    var lastUpdated = _parseLastUpdatedTime(document);

    var rows = document.querySelectorAll('#GridView1 > tbody > tr');
    for (var row in rows) {
      var cells = row.querySelectorAll('td');
      if (cells.length < 7) continue;
      var trainNo = cells[5].text.trim();
      if (int.tryParse(trainNo) == null) continue;
      var rawStatus = cells[6].text.trim();
      var stop = stopByTrainNo(trainNo, station.stopId);

      TrainStatus status = _parseRawStatus(rawStatus, lastUpdated, stop);
      if (status == null) {
        print('Unable to parse status for train $trainNo from ${station.stationName} (stopId ${stop.id()}):');
        print('$rawStatus');
      } else {
        addStatus(status);
        ++statusesFound;
      }
    }

    print('Found $statusesFound statuses');

    if (Config.writeCache && statusesFound > 0) {
      _tryWriteCacheFile(station, html);
    }
  }

  static SharedPreferences _prefs;
  static Future _loadPrefs() async { 
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
  }
  static const _watchedStopsKey = 'ChooChooWatchedStopsKey';
  static List<WatchedStop> loadWatchedStopsFromJson(String jsonStr) {
    print('loadWatchedStopsFromJson($jsonStr)');
    List<dynamic> watchedStopsJson = json.decode(jsonStr);
    return watchedStopsJson.map<WatchedStop>((wsJson) => _watchedStopFromJson(wsJson)).toList();
  }
  static Future _saveWatchedStops() async {
    await _loadPrefs();
    String json = watchedStopsToJson(watchedStops.values.toList());
    print('Saving watchedStops:\n$json');
    _prefs.setString(_watchedStopsKey, json);
  }
  static String watchedStopsToJson(List<WatchedStop> watchedStops) {
    return json.encode(watchedStops.map((ws) => _watchedStopToJson(ws)).toList());
  }

  static WatchedStop _watchedStopFromJson(Map<String, dynamic> json) {
    print('_watchedStopFromJson(${json["tripId"]}, ${json["departureStationId"]})');
    return WatchedStop(stopByTripId(json['tripId'], json['departureStationId']), 
                       List<int>.from(json['days']));
  }

  static Map<String, dynamic> _watchedStopToJson(WatchedStop ws) => {
    'tripId': ws.stop.train.tripId,
    'departureStationId': ws.stop.departureStation.stopId,
    'days': ws.days
  };
}