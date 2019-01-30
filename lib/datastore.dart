// Datastore for data loaded from disk, DepartureVision, or user preferences.
//
// Call Datastore.loadDataFiles() once when the app is initialized to load the 
// base data for trains and stops. Then call Datastore.refreshStatuses() to 
// load live data from DepartureVision on demand.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_utils.dart';
import 'model.dart';

class Datastore {
  static final Map<String, Station> stationsByStationName = new Map();
  static final Map<int, Station> stationsByStopId = new Map();

  static final Map<int, Train> trainsByTripId = new Map();
  static final Map<String, int> trainNoToTripId = new Map();

  // Index of stops on tripId|fromStationId, loaded from the data files.
  static final Map<String, Stop> _stopsByTripId = Map();

  // The current set of statuses, keyed on Stop.id().
  static final Map<String, TrainStatus> _statuses = Map();

  static SharedPreferences _prefs = _getSharedPreferences();
  static final List<WatchedStop> watchedStops = List();

  static Train trainFromTrainNo(String trainNo) {
    if (!trainNoToTripId.containsKey(trainNo)) {
      print('Unknmown trainNo: $trainNo');
      return null;
    }
    return trainsByTripId[trainNoToTripId[trainNo]];
  }
  
  static Stop stopByTripId(int tripId, int depatureStationId) {
    return _stopsByTripId[Stop.idFromRaw(tripId, depatureStationId)];
  }

  static Stop stopByTrainNo(String trainNo, int departureStationId) {
    return stopByTripId(trainNoToTripId[trainNo], departureStationId);
  }

  static List<TrainStatus> statusesInOrder() {
    var statuses = _statuses.values.toList();
    statuses.sort((a, b) => a.getDepartureTime().compareTo(b.getDepartureTime()));
    return statuses;
  }

  // Load data from files.
  static Future loadDataFiles(AssetBundle bundle) async {
    if (stationsByStationName.isNotEmpty && 
        trainsByTripId.isNotEmpty &&
        _stopsByTripId.isNotEmpty) {
      print('loadDataFiles(): already loaded (${stationsByStationName.length} stations, ' +
            '${trainsByTripId.length} Trains, ${_stopsByTripId.length} Stops)');
      return;
    }
    print('Loading datafiles...');
    var start = DateTime.now();
    await _loadStations(bundle);
    await _loadTrains(bundle);
    await _loadStops(bundle);
    
    var timing = DateTime.now().difference(start).inMilliseconds;
    print('Loaded data files in ${timing}ms.');
  }

  static _getSharedPreferences() async { await SharedPreferences.getInstance(); }
  static const _watchedStopsKey = 'ChooChooWatchedStopsKey';
  static Future loadWatchedStops() async {
    watchedStops.insertAll(0, loadWatchedStopsFromJson(_prefs.getString(_watchedStopsKey) ?? '[]'));
  }
  static List<WatchedStop> loadWatchedStopsFromJson(String jsonStr) {
    List<dynamic> watchedStopsJson = json.decode(jsonStr);
    return watchedStopsJson.map<WatchedStop>((wsJson) => _watchedStopFromJson(wsJson)).toList();
  }

  static Future saveWatchedStops() async {
    _prefs.setString(_watchedStopsKey, watchedStopsToJson(watchedStops));
  }
  static String watchedStopsToJson(List<WatchedStop> watchedStops) {
    return json.encode(watchedStops.map((ws) => _watchedStopToJson(ws)).toList());
  }

  static Future addWatchedStop(WatchedStop ws) async {
    watchedStops.add(ws);
    await saveWatchedStops();
  }

  static WatchedStop _watchedStopFromJson(Map<String, dynamic> json) {
    return WatchedStop(stopByTripId(json['tripId'], json['departureStationId']), 
                       List<int>.from(json['days']));
  }

  static Map<String, dynamic> _watchedStopToJson(WatchedStop ws) => {
    'tripId': ws.stop.train.tripId,
    'departureStationId': ws.stop.departureStation.stopId,
    'days': ws.days
  };

  // Refresh the list of statuses for the given station, either directly from
  // the DepartureVision site, or using the cache (if available and fresh). 
  static const _defaultMaxCacheAgeInMinutes = 5;
  static Future refreshStatuses(String stationName, 
                                AssetBundle bundle,
                                [ bool readCache = false,
                                  bool writeCache = false,
                                  int maxCacheAgeInMinutes = _defaultMaxCacheAgeInMinutes ]) async {
    await loadDataFiles(bundle);
    print('Refreshing statuses...');
    var start = DateTime.now();
    Station station = stationsByStationName[stationName];
    String html = await _fetchDepartureVision(station, readCache, maxCacheAgeInMinutes);
    await _parseDepartureVision(html, station, bundle, writeCache, maxCacheAgeInMinutes);

    var timing = DateTime.now().difference(start).inMilliseconds;
    print('Loaded statuses in ${timing}ms.');
  }

  static Future _loadStations(AssetBundle bundle) async {
    // TODO: probably want to have some sort of real lock while loading data so we don't
    // have two concurrent processes loading at the same time. Also, just checking for 
    // non-empty probably isn't enough to validate that the data loaded correctly.
    Map<String, String> stationToChar = new Map();
    for (var row in await FileUtils.csvFileToArray('station2char.csv', bundle)) {
      stationToChar[row[0]] = row[1].toString().trim();
    }

    for (var row in await FileUtils.csvFileToArray('stops.txt', bundle)) {
      if (row[0] == 'stop_id') continue;  // Skip header.
      int stopId = row[0];
      String stationName = row[2];
      Station station = new Station(stationName, stationToChar[stationName], stopId);
      stationsByStationName[stationName] = station;
      stationsByStopId[stopId] = station;
    }

    print('Loaded ${stationsByStationName.length} stations from stops.txt');
  }

  static RegExp _removeLeadingZeros = new RegExp(r'^0+(?!$)');
  static String _fixTrainNo(String rawTrainNo) {
    return rawTrainNo.replaceFirst(_removeLeadingZeros, '');
  }
  static Future _loadTrains(AssetBundle bundle) async {
    // TODO: distinguish by service_id for the current date (weekend vs. weekday). Need to join
    // with the calendar_dates.txt file?
    for (var row in await FileUtils.csvFileToArray('trips.txt', bundle)) {
      if (row[0] == 'route_id') continue;  // Skip header.
      int tripId = row[2];
      String trainNo = _fixTrainNo(row[5]);
      trainsByTripId[tripId] = new Train(trainNo, stationsByStationName[row[3]], tripId);
      trainNoToTripId[trainNo] = tripId;
    }
    print('Loaded ${trainsByTripId.length} trains');
    return;
  }

  static final DateFormat _hourMinuteSecondsFormat = new DateFormat.Hms();
  static Future _loadStops(AssetBundle bundle) async {    
    for (var row in await FileUtils.csvFileToArray('stop_times.txt', bundle)) {
      if (row[0] == 'trip_id') continue;  // Skip header.
      var tripId = row[0];
      var departureStationId = row[3];
      Train train = trainsByTripId[tripId];
      Stop stop = new Stop(train, stationsByStopId[departureStationId], _hourMinuteSecondsFormat.parse(row[2]));
      _stopsByTripId[stop.id()] = stop;
    }

    print('Loaded ${_stopsByTripId.length} trains from stop_times.txt');    

    return _stopsByTripId;
  }

  static bool _isCacheFileFresh(File cacheFile, int maxCacheAgeInMinutes) {
    return (DateTime.now().difference(cacheFile.lastModifiedSync()).inMinutes < maxCacheAgeInMinutes);
  }
  // Try to read the cache file for the given station. Returns null if the 
  // cache file is out of date or nonexistant.
  static Future<String> _tryReadCacheFile(Station station, int maxCacheAgeInMinutes) async {
    File cacheFile = await FileUtils.getCacheFile(station.stationName);
    if (cacheFile.existsSync()) {
      if (_isCacheFileFresh(cacheFile, maxCacheAgeInMinutes)) {
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
  static Future _tryWriteCacheFile(Station station, String html, int maxCacheAgeInMinutes) async {
    File cacheFile = await FileUtils.getCacheFile(station.stationName);
    if (_isCacheFileFresh(cacheFile, maxCacheAgeInMinutes)) {
      print('Existing cache is still fresh, no need to overwrite.');
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
  static Future<String> _fetchDepartureVision(Station station, bool useCache, int maxCacheAgeInMinutes) async {
    String cached = (useCache) ? await _tryReadCacheFile(station, maxCacheAgeInMinutes) : null;
    if (null != cached) {
      return cached;
    }

    HttpClient http = HttpClient();
    try {
      var uri = Uri.http('dv.njtransit.com', '/mobile/tid-mobile.aspx', {'sid': station.twoLetterCode});
      print('Fetching $uri');
      var request = await http.getUrl(uri);
      var response = await request.close();
      var responseBody = await response.transform(utf8.decoder).join();
      print('Response ${responseBody.substring(0, 50)}');
      return responseBody;
    } catch (exception) {
      print(exception);
      return '';
    }
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
      return TrainStatus(stop, rawStatus, TrainState.NotPosted, stop.scheduledDepartureTime, DateTime.now());
    } else if (_inNMinutesRe.hasMatch(rawStatus)) {
      var minutesDelayed = int.parse(_inNMinutesRe.firstMatch(rawStatus).group(1));
      var calculatedDeparture = lastUpdated.add(new Duration(minutes: minutesDelayed));
      var diff = calculatedDeparture.difference(stop.scheduledDepartureTime).inMinutes;
      var state = () {
        if (diff == 0) return TrainState.OnTime;
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
  static Future _parseDepartureVision(String html, Station station, AssetBundle bundle, bool useCache, int maxCacheAgeInMinutes) async {
    var stopsFound = 0;

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
        _statuses[stop.id()] = status;
        ++stopsFound;
      }
    }

    print('Found $stopsFound stops');

    if (useCache && stopsFound > 0) {
      _tryWriteCacheFile(station, html, maxCacheAgeInMinutes);
    }
  }
}