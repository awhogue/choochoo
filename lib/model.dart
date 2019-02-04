import 'display_utils.dart';

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
  // Assumes that the NJ transit tripIds are always less than 1000000.
  int id() {
    return idFromRaw(train.tripId, departureStation.stopId);
  }
  static int idFromRaw(int tripId, int departureStationId) {
    // Pad the tripId to 7 digits, then prepend the departure station to make a unique, 
    // hopefully stable int ID.
    var paddedTripId = tripId.toString().padLeft(7, '0');
    return int.parse('$departureStationId$paddedTripId');
  }

  @override
  String toString() {
    return 
      '$train from $departureStation ' +
      'at ${DisplayUtils.timeDisplayFormat.format(scheduledDepartureTime)}';
  }

  // Return the date and time of the next scheduled departure for this train.
  DateTime nextScheduledDeparture() {
    var now = DateTime.now();
    var next = new DateTime(
      now.year, now.month, now.day, 
      scheduledDepartureTime.hour, scheduledDepartureTime.minute);

    // The train already departed today.
    if (now.isAfter(next)) {
      next = next.add(Duration(days: 1));
    }

    // TODO: handle non-weekday trains (and holidays!) using calendar_dates.txt
    if (next.weekday == DateTime.saturday) {
      next = next.add(Duration(days: 2));
    } else if (next.weekday == DateTime.sunday) {
      next = next.add(Duration(days: 1));
    }

    return next;
  }
}

enum TrainState {
  NotPosted,
  OnTime,
  Late,
  Early,
  AllAboard,
  Canceled,
  Unknown,
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

  @override
  String toString() {
    var rawStatusStr = (rawStatus.isEmpty) ? '' : '$rawStatus, ';
    return 
      'Status for ${stop.train.trainNo} to ${stop.train.destinationStation} ' + 
      '${DisplayUtils.shortStatus(this)}: ${DisplayUtils.timeStatus(this)} ' +
      '(${rawStatusStr}updated ${DisplayUtils.timeDisplayFormat.format(lastUpdated)})';
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
    return 'WatchedStop $stop on $days';
  }
}