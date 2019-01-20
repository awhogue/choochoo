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
}

// A live train status from departure vision.
class TrainStatus {
  // The tripId of the train.
  final int tripId;
  // The raw status from DepartureVision (e.g. "in 22 minutes" or "CANCELLED").
  final String rawStatus;
  // The actual departure time calculated from the rawStatus. If the train is canceled or no status has been posted, 
  // this will be null.
  final DateTime calculatedDepartureTime;

  TrainStatus(this.tripId, this.rawStatus, this.calculatedDepartureTime);
}