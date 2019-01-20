import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'model.dart';

// A single sation stop on the NJ Transit system.
class Station {
  // The user-visible name of the station.
  final String stationName;
  // The two-letter code used by the DepartureVision system for this station.
  final String twoLetterCode;
  // The integer ID for the station (called a "stop") in the NJ Transit data files.
  final int stopId;

  Station(this.stationName, this.twoLetterCode, this.stopId);
}

// A scheduled train from a station with a departure time. 
// TODO: Distinguish between weekday/holiday trains with the same user-facing trainNo but different tripIds.
class Train {
  // The customer-facing train number.
  final String trainNo; 
  // The Station from which this train is departing.
  final int fromStationId;
  // The name of the destination for this train.
  final String destinationStation;
  // The scheduled time of departure for this train.
  final DateTime scheduledDepartureTime;
  // The integer ID for this train (called a "trip") in the NJ Transit data files.
  final int tripId;

  Train(this.trainNo, this.fromStationId, this.destinationStation, this.scheduledDepartureTime, this.tripId);
  Train.fromTripsFile(String trainNo, int tripId, String destinationStation)
    : this.trainNo = trainNo, 
      this.tripId = tripId,
      this.fromStationId = null,
      this.destinationStation = destinationStation,
      this.scheduledDepartureTime = null;

  final _csvCodec = new CsvCodec();
  final DateFormat hourMinuteSecondsFormat = new DateFormat.jms();
  Future loadTrains() async {
    final tripsFile = new File('njtransit_data/trips.txt').openRead();
    final tripsFields = await tripsFile.transform(utf8.decoder).transform(_csvCodec.decoder);

    Map<int, Train> partialTrains = Map();
    await for (var row in tripsFields) {
      partialTrains[row[2]] = Train.fromTripsFile(row[5], row[2], row[3]);
    }

    final stopTimesFile = new File('njtransit_data/stop_times.txt').openRead();
    final stopTimesFields = await stopTimesFile.transform(utf8.decoder).transform(_csvCodec.decoder);

    List<Train> trains = List();
    await for (var row in stopTimesFields) {
      var tripId = row[0];
      if (partialTrains.containsKey(tripId)) {
        var partial = partialTrains[tripId];
        var departureTime = hourMinuteSecondsFormat.parse(row[2]);
        trains.add(new Train(partial.trainNo, row[3], partial.destinationStation, departureTime, tripId));
      } else {
        print('Could not find tripId $tripId in partialTrains? Row: $row');
      }
    }

    return trains;
  }
}

// A live train status from departure vision.
class TrainStatus {
  // The Train this status is associated with.
  final Train train;
  // The raw status from DepartureVision (e.g. "in 22 minutes" or "CANCELLED").
  final String rawStatus;
  // The actual departure time calculated from the rawStatus. If the train is canceled or no status has been posted, 
  // this will be null.
  final DateTime calculatedDepartureTime;

  TrainStatus(this.train, this.rawStatus, this.calculatedDepartureTime);

  Future getStatuses(String station) async {
    HttpClient http = HttpClient();
    try {
      var uri = Uri.http('dv.njtransit.com', '/mobile/tid-mobile.aspx', {'sid': station});
      var request = await http.getUrl(uri);
      var response = await request.close();
      var responseBody = await response.transform(utf8.decoder).join();
      print('Response ${responseBody.substring(0, 50)}');

      List<TrainStatus> statuses = new List<TrainStatus>();
      var document = parse(responseBody);
      var rows = document.querySelectorAll('#GridView1 > tbody > tr');
      print('Found ${rows.length} rows');
      for (var row in rows) {
        var cells = row.querySelectorAll('td');

        statuses.add(TrainStatus())
      }
    } catch (exception) {
      print(exception);
    }
  )
}