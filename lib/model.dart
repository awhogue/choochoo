import 'display_utils.dart';

// Represents a time (without a date associated with it).
// (Because Dart only has a DateTime class and we need to just represent "8:03am"\
// without associating it with a particular day).
class Time {
  int hour; // 0-23
  int minute; // 0-59
  Time(this.hour, this.minute);
  static Time fromDateTime(DateTime dt) => Time(dt.hour, dt.minute);

  @override
  String toString() {
    var ampm = (hour < 12) ? 'AM' : 'PM';
    return '${hour % 12}:$minute $ampm';
  }
}

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
  final Time scheduledDepartureTime;
  // What days of the week the train runs. Defaults to every day until...
  // TODO: load handle non-weekday trains (and holidays!) using calendar_dates.txt
  final List<int> serviceDays;
  static const List<int> weekdays = [DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday];
  static const List<int> weekends = [DateTime.saturday, DateTime.sunday];
  static const List<int> everyday = [DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday, DateTime.saturday];

  Stop(this.train, this.departureStation, this.scheduledDepartureTime, this.serviceDays);

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

  String departureTimeString() {
    return scheduledDepartureTime.toString();
  }

  @override
  String toString() {
    return 
      '#${train.trainNo} ${departureTimeString()} ' +
      '${departureStation.stationName}->${train.destinationStation.stationName}';
  }

  // Return a full DateTime (including year/month/day) for today's departure (even if it's already passed).
  DateTime todaysDeparture() {
    var now = DateTime.now();
    return DateTime(
      now.year, now.month, now.day, 
      scheduledDepartureTime.hour, scheduledDepartureTime.minute);
  }

  // Return the date and time of the next scheduled departure for this train.
  DateTime nextScheduledDeparture() {
    var now = DateTime.now();
    var departureToday = todaysDeparture();
    if (now.isBefore(departureToday) && 
        this.serviceDays.contains(departureToday.weekday)) {
      print('Next departure: $departureToday');
      return departureToday;
    } else {
      // For now, just go to tomorrow's departure.
      // TODO: calculate the correct next day that has a departure (e.g. if it's the weekend)
      var departureTomorrow = departureToday.add(Duration(days: 1));
      print('Next departure: $departureTomorrow');
      return departureTomorrow;
    }
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
      'Status for ${trainNo()} to ${stop.train.destinationStation} ' + 
      '${DisplayUtils.shortStatus(this)}: ${DisplayUtils.timeStatus(this)} ' +
      '(${rawStatusStr}updated ${DisplayUtils.timeDisplayFormat.format(lastUpdated)})';
  }

  Time departureTime() => stop.scheduledDepartureTime;
  DateTime todaysScheduledDeparture() => stop.todaysDeparture();
  DateTime nextScheduledDeparture() => stop.nextScheduledDeparture();

  String trainNo() => stop.train.trainNo;
  String departureStationName() => stop.departureStation.stationName;
  String destinationStationName() => stop.train.destinationStation.stationName;

  // Return the best known departure time for this train, meaning the scheduled time if no
  // status has been posted, or the calculated time if one has.
  DateTime getTodaysDepartureTime() {
    if (calculatedDepartureTime == null) {
      return todaysScheduledDeparture();
    } else {
      return calculatedDepartureTime;
    }
  }

  // How long from now until departure?
  int getMinutesUntilDeparture() {
    var dur = calculatedDepartureTime.difference(DateTime.now());
    return dur.inMinutes;
  }

  // How late/early is the the train versus schedule?
  int getMinutesLateEarly() {
    return calculatedDepartureTime.difference(todaysScheduledDeparture()).inMinutes;
  }
}

// Represents a stop that a user is "watching" (i.e. wants to get notifications for).
class WatchedStop {
  Stop stop;
  // The days of the week that the user cares about (list of DateTime.weekday ints).
  // Can use the constants defined in Stop.
  List<int> days;

  WatchedStop(this.stop, this.days);

  @override 
  String toString() {
    return 'WS: $stop on $days';
  }

  DateTime nextScheduledDeparture() => stop.nextScheduledDeparture();
}