import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart';
import 'package:intl/intl.dart';

// A single sation stop on the NJ Transit system.
class Station {
  // The user-visible name of the station.
  final String stationName;
  // The two-letter code used by the DepartureVision system for this station.
  final String twoLetterCode;
  // The integer ID for the station (called a "stop") in the NJ Transit data files.
  final int stopId;

  Station(this.stationName, this.twoLetterCode, this.stopId);

  static final Map<String, Station> byStationName = new Map();
  static final Map<int, Station> byStopId = new Map();

  @override
  String toString() {
    return '$stationName ($twoLetterCode, $stopId)';
  }

  static final _csvCodec = new CsvCodec(eol: '\n');
  static Future loadStations() async {
    if (byStationName.isNotEmpty) {
      print('${byStationName.length} Stations already loaded.');
    } else {
      print('Loading station2char.csv');
      Map<String, String> stationToChar = new Map();
      {
        final file = new File('njtransit_data/station2char.csv').openRead();
        final fields = file.transform(utf8.decoder).transform(_csvCodec.decoder);

        await for (var row in fields) {
          stationToChar[row[0]] = row[1].toString().trim();
        }
      }

      print('Loading stops.txt...');
      final file = new File('njtransit_data/stops.txt').openRead();
      final fields = file.transform(utf8.decoder).transform(_csvCodec.decoder);

      await for (var row in fields) {
        if (row[0] == 'stop_id') continue;  // Skip header.
        int stopId = row[0];
        String stationName = row[2];
        Station station = new Station(stationName, stationToChar[stationName], stopId);
        byStationName[stationName] = station;
        byStopId[stopId] = station;
      }

      print('Loaded ${byStationName.length} stations from stops.txt');
    }
  }
}

// A train making multiple stops going towards a destination.
class Train {
  // The customer-facing train number.
  final String trainNo; 
  // The name of the destination for this train.
  final Station destinationStation;
  // The integer ID for this train (called a "trip") in the NJ Transit data files.
  final int tripId;

  Train(this.trainNo, this.destinationStation, this.tripId);

  static final Map<int, Train> byTripId = new Map();
  static final Map<String, int> trainNoToTripId = new Map();

  static Train byTrainNo(String trainNo) {
    if (!trainNoToTripId.containsKey(trainNo)) {
      print('Unknmown trainNo: $trainNo');
      return null;
    }
    return byTripId[trainNoToTripId[trainNo]];
  }
  
  @override
  String toString() {
    return 'Train $trainNo (tripId ${tripId.toString()}) to $destinationStation';
  }

  static RegExp removeLeadingZeros = new RegExp(r'^0+(?!$)');
  static String _fixTrainNo(String rawTrainNo) {
    return rawTrainNo.replaceFirst(removeLeadingZeros, '');
  }
  static final _csvCodec = new CsvCodec(eol: '\n');
  static Future loadTrains() async {
    await Station.loadStations();

    if (byTripId.isNotEmpty) {
      print('${byTripId.length} Trains already loaded.');
    } else {
      print('Loading trips.txt...');
      final file = new File('njtransit_data/trips.txt').openRead();
      final fields = file.transform(utf8.decoder).transform(_csvCodec.decoder);

      // TODO: distinguish by service_id for the current date (weekend vs. weekday). Need to join
      // with the calendar_dates.txt file?
      await for (var row in fields) {
        if (row[0] == 'route_id') continue;  // Skip header.
        int tripId = row[2];
        String trainNo = _fixTrainNo(row[5]);
        byTripId[tripId] = new Train(trainNo, Station.byStationName[row[3]], tripId);
        trainNoToTripId[trainNo] = tripId;
      }
      print('Loaded ${byTripId.length} trains from trips.txt');
    }
  }
}

// A scheduled train stop at a station with a departure time.
// Uniquely identified by the train plus the departure station.
// TODO: Distinguish between weekday/holiday trains with the same user-facing trainNo but different tripIds.
class Stop {
  // The Train that this stop is part of.
  final Train train;
  // The Station from which this train is departing.
  final Station departureStation;
  // The scheduled time of departure for this train.
  final DateTime scheduledDepartureTime;

  // Index of stops on tripId|fromStationId, loaded from the data files.
  static final Map<String, Stop> _stopsByTripId = Map();

  static final DateFormat _hourMinuteSecondsFormat = new DateFormat.Hms();

  Stop(this.train, this.departureStation, this.scheduledDepartureTime);

  // A unique identifier for this Stop using train.tripId and departureStation.stopId.
  String id() {
    return _key(train.tripId, departureStation.stopId);
  }

  static Stop byTripId(int tripId, int depatureStationId) {
    return _stopsByTripId[_key(tripId, depatureStationId)];
  }

  static Stop byTrainNo(String trainNo, int departureStationId) {
    return byTripId(Train.trainNoToTripId[trainNo], departureStationId);
  }

  static String _key(int tripId, int departureStationId) {
    return '$tripId|$departureStationId';
  }

  @override
  String toString() {
    return 
      '$train from $departureStation ' +
      'at ${_hourMinuteSecondsFormat.format(scheduledDepartureTime)}';
  }

  static final _csvCodec = new CsvCodec(eol: '\n');
  static Future loadStops() async {
    await Station.loadStations();
    await Train.loadTrains();
    
    if (_stopsByTripId.isNotEmpty) {
      print('${_stopsByTripId.length} Stops already loaded.');
    } else {
      print('Loading stop_times.txt...');
      final file = new File('njtransit_data/stop_times.txt').openRead();
      final fields = file.transform(utf8.decoder).transform(_csvCodec.decoder);

      await for (var row in fields) {
        if (row[0] == 'trip_id') continue;  // Skip header.
        var tripId = row[0];
        var departureStationId = row[3];
        Train train = Train.byTripId[tripId];
        Stop stop = new Stop(train, Station.byStopId[departureStationId], _hourMinuteSecondsFormat.parse(row[2]));
        _stopsByTripId[_key(tripId, departureStationId)] = stop;
      }

      print('Loaded ${_stopsByTripId.length} trains from stop_times.txt');    

      return _stopsByTripId;
    }
  }
}

// A live train status from departure vision.
class TrainStatus {
  // The Stop this status is associated with.
  final Stop stop;
  // The raw status from DepartureVision (e.g. "in 22 minutes" or "CANCELLED").
  final String rawStatus;
  // The actual departure time calculated from the rawStatus. If the train is canceled or no status has been posted, 
  // this will be null.
  final DateTime calculatedDepartureTime;
  // The last time this status was successfully refreshed from the server.
  final DateTime lastUpdated;

  TrainStatus(this.stop, this.rawStatus, this.calculatedDepartureTime, this.lastUpdated);

  // The current set of statuses, keyed on Stop.id().
  static final Map<String, TrainStatus> _statuses = Map();

  static final DateFormat _timeDisplayFormat = new DateFormat.jm();
  @override
  String toString() {
    var departureStr = '';
    if (calculatedDepartureTime == null) {
      departureStr = 'no status yet; scheduled to depart at ${_timeDisplayFormat.format(stop.scheduledDepartureTime)}';
    } else if (calculatedDepartureTime.hour == stop.scheduledDepartureTime.hour &&
               calculatedDepartureTime.minute == stop.scheduledDepartureTime.minute) {
      departureStr = 'on time at ${_timeDisplayFormat.format(stop.scheduledDepartureTime)}';
    } else {
      var lateStr = (calculatedDepartureTime.isAfter(stop.scheduledDepartureTime)) ? 'late' : 'early?!';
      var diff = calculatedDepartureTime.difference(stop.scheduledDepartureTime).abs();
      departureStr = 
        'running ${diff.inMinutes} minutes $lateStr (scheduled ${_timeDisplayFormat.format(stop.scheduledDepartureTime)} ' +
        'actual ${_timeDisplayFormat.format(calculatedDepartureTime)})';
    }
    var rawStatusStr = (rawStatus.isEmpty) ? '' : '$rawStatus, ';
    return 
      'Status for ${stop.train.trainNo} to ${stop.train.destinationStation}: ' +
      '$departureStr (${rawStatusStr}updated ${_timeDisplayFormat.format(lastUpdated)})';
  }

  static Future refreshStatuses(String stationName) async {
    await Station.loadStations();

    var station = Station.byStationName[stationName];
    String html = await fetchDepartureVision(station);
    parseDepartureVision(html, station);
  }

  static Future<String> fetchDepartureVision(Station station) async {
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
  static DateTime _parseLastUpdatedTime(Document document) {
    // Select all the divs because status messages sometimes pop up with weird formatting.
    var div = document.querySelector('#Label2');
    if (_updatedTimeRe.hasMatch(div.text)) {
      var timeStr = _updatedTimeRe.firstMatch(div.text).group(1);
      print('Found div ${div.text} with timeStr $timeStr');
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
      return TrainStatus(stop, rawStatus, null, DateTime.now());
    } else if (_inNMinutesRe.hasMatch(rawStatus)) {
      var minutesDelayed = int.parse(_inNMinutesRe.firstMatch(rawStatus).group(1));
      var calculatedDeparture = lastUpdated.add(new Duration(minutes: minutesDelayed));
      return TrainStatus(stop, rawStatus, calculatedDeparture, lastUpdated);
    } else {
      return null;
    }
  }
  // Parse a departurevision HTML file.
  static Future parseDepartureVision(String html, Station station) async {
    await Stop.loadStops();

    var document = parse(html);
    var lastUpdated = _parseLastUpdatedTime(document);

    var rows = document.querySelectorAll('#GridView1 > tbody > tr');
    for (var row in rows) {
      var cells = row.querySelectorAll('td');
      if (cells.length < 7) continue;
      var trainNo = cells[5].text.trim();
      if (int.tryParse(trainNo) == null) continue;
      var rawStatus = cells[6].text.trim();
      var stop = Stop.byTrainNo(trainNo, station.stopId);

      TrainStatus status = _parseRawStatus(rawStatus, lastUpdated, stop);
      if (status == null) {
        print('Unable to parse status for train $trainNo from ${station.stationName} (stopId ${stop.id()}):');
        print('$rawStatus');
      } else {
        print(status);
        _statuses[stop.id()] = status;
      }
    }
  }
}