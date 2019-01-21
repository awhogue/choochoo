import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:html/parser.dart';
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
          stationToChar[row[0]] = row[1].toString();
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
        String trainNo = row[5];
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

  static final DateFormat hourMinuteSecondsFormat = new DateFormat.Hms();

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
      'at ${hourMinuteSecondsFormat.format(scheduledDepartureTime)}';
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
        Stop stop = new Stop(train, Station.byStopId[departureStationId], hourMinuteSecondsFormat.parse(row[2]));
        _stopsByTripId['$tripId|$departureStationId'] = stop;
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

  @override
  String toString() {
    return 'Status for $stop: $rawStatus departing at $calculatedDepartureTime (updated $lastUpdated)';
  }

  static RegExp delayedRe = new RegExp(r'in (\d+) Min');
  static Future refreshStatuses(String stationName) async {
    await Station.loadStations();
    await Stop.loadStops();

    var station = Station.byStationName[stationName];
    HttpClient http = HttpClient();
    try {
      var uri = Uri.http('dv.njtransit.com', '/mobile/tid-mobile.aspx', {'sid': stationName});
      var request = await http.getUrl(uri);
      var response = await request.close();
      var responseBody = await response.transform(utf8.decoder).join();
      print('Response ${responseBody.substring(0, 50)}');

      var document = parse(responseBody);
      var rows = document.querySelectorAll('#GridView1 > tbody > tr');
      print('Found ${rows.length} rows');
      for (var row in rows) {
        var cells = row.querySelectorAll('td');
        var trainNo = cells[4].text;
        var rawStatus = cells[5].text;
        var stop = Stop.byTrainNo(trainNo, station.stopId);
        if (rawStatus.isEmpty) {
          _statuses[stop.id()] = TrainStatus(stop, rawStatus, null, DateTime.now());
        } else if (delayedRe.hasMatch(rawStatus)) {
          var minutesDelayed = int.parse(delayedRe.firstMatch(rawStatus).group(0));
          var status = TrainStatus(
            stop, rawStatus, 
            stop.scheduledDepartureTime.add(new Duration(minutes: minutesDelayed)), 
            DateTime.now()
          );
          print(status);
          _statuses[stop.id()] = status;
        } else {
          print('Unknown status for train $trainNo from $stationName (stop.id() ${stop.id()}: $rawStatus');
        }        
      }
    } catch (exception) {
      print(exception);
    }
  }
}