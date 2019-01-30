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

  @override
  String toString() {
    return '$stationName ($twoLetterCode, $stopId)';
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

  @override
  String toString() {
    return 'Train $trainNo (tripId ${tripId.toString()}) to $destinationStation';
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

  Stop(this.train, this.departureStation, this.scheduledDepartureTime);

  // A unique identifier for this Stop using train.tripId and departureStation.stopId.
  String id() {
    return idFromRaw(train.tripId, departureStation.stopId);
  }

  static String idFromRaw(int tripId, int departureStationId) {
    return '$tripId|$departureStationId';
  }

  static final DateFormat _timeDisplayFormat = new DateFormat.jm();
  @override
  String toString() {
    return 
      '$train from $departureStation ' +
      'at ${_timeDisplayFormat.format(scheduledDepartureTime)}';
  }
}

enum TrainState {
  NotPosted,
  OnTime,
  Late,
  Early,
  AllAboard,
  Canceled,
}

// A live train status from departure vision.
class TrainStatus {
  // The Stop this status is associated with.
  final Stop stop;
  // The raw status from DepartureVision (e.g. "in 22 minutes" or "CANCELLED").
  final String rawStatus;
  // A semantically parsed status state for the train, e.g. "canceled".
  final TrainState state;
  // The actual departure time calculated from the rawStatus. If the train is canceled or no status has been posted, 
  // this will be null.
  final DateTime calculatedDepartureTime;
  // The last time this status was successfully refreshed from the server.
  final DateTime lastUpdated;

  TrainStatus(this.stop, this.rawStatus, this.state, this.calculatedDepartureTime, this.lastUpdated);

  static final DateFormat _timeDisplayFormat = new DateFormat.jm();
  @override
  String toString() {
    var rawStatusStr = (rawStatus.isEmpty) ? '' : '$rawStatus, ';
    var status = statusForDisplay();
    return 
      'Status for ${stop.train.trainNo} to ${stop.train.destinationStation} ' + 
      '${status[0]}: ${status[1]} ' +
      '(${rawStatusStr}updated ${_timeDisplayFormat.format(lastUpdated)})';
  }

  String _minutesStr(int minutes) {
    if (minutes == 0) return 'on time';
    var minStr = (minutes.abs() == 1) ? 'minute' : 'minutes';
    var lateStr = (minutes > 0) ? 'late' : 'early!';
    return '$minutes $minStr $lateStr';
  }

  // Returns two strings: The first is the actual time of departure (either scheduled or calculated). 
  // The second is a status message (e.g. "6 minutes late" or "not yet posted").
  List<String> statusForDisplay() {
    switch (state) {
      case TrainState.NotPosted: 
        return ['',
                'not yet posted'];
      case TrainState.OnTime:
        return [_timeDisplayFormat.format(stop.scheduledDepartureTime),
                'on time'];
      case TrainState.Late:
      case TrainState.Early: {
        var calculatedDepartureDiff = calculatedDepartureTime.difference(stop.scheduledDepartureTime).inMinutes;
        return ['now at ${_timeDisplayFormat.format(calculatedDepartureTime)}',
                _minutesStr(calculatedDepartureDiff)];
      }
      case TrainState.AllAboard: {
        var allAboardDiff = DateTime.now().difference(stop.scheduledDepartureTime).inMinutes;
        return ['ALL ABOARD',
                _minutesStr(allAboardDiff)];
      }
      case TrainState.Canceled: 
        return ['CANCELED', ''];
    }
    return [rawStatus, '(unknown status)'];
  }

  // Return the best known departure time for this train, meaning the scheduled time if no
  // status has been posted, or the calculated time if one has.
  DateTime getDepartureTime() {
    if (calculatedDepartureTime == null) {
      return stop.scheduledDepartureTime;
    } else {
      return calculatedDepartureTime;
    }
  }
}

// Represents a stop that a user is "watching" (i.e. wants to get notifications for).
class WatchedStop {
  Stop stop;
  // The days of the week that the user cares about (list of DateTime.weekday ints).
  List<int> days;
  static const List<int> weekdays = [DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday];
  static const List<int> weekends = [DateTime.saturday, DateTime.sunday];

  WatchedStop(this.stop, this.days);

  @override 
  String toString() {
    return 'WatchedStop ${stop.departureStation.stationName} on $days';
  }
}