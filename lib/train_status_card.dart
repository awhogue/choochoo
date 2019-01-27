// Visual representation of one train stop at a station with a status 
// (scheduled time, actual time, canceled, etc.).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'model.dart';

class TrainStatusCard extends StatefulWidget {
  final TrainStatus status;
  TrainStatusCard(this.status);

  @override
  _TrainStatusCardState createState() => _TrainStatusCardState(status);
}

class _TrainStatusCardState extends State<TrainStatusCard> {
   TrainStatus status;

   _TrainStatusCardState(this.status);

  static final DateFormat _timeDisplayFormat = new DateFormat.jm();

  @override
  Widget build(BuildContext context) {
    var statusMessages = status.statusForDisplay();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Train #${status.stop.train.trainNo}',
                  style: Theme.of(context).textTheme.title,
                ),
              ),
              Text(
                statusMessages[1],
                style: Theme.of(context).textTheme.title,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  statusMessages[0],
                  style: Theme.of(context).textTheme.body1,
                ),
              ),
              Text('Scheduled: ${_timeDisplayFormat.format(status.stop.scheduledDepartureTime)}'),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '(as of ${_timeDisplayFormat.format(status.lastUpdated)})',
                  textAlign: TextAlign.right,
                ),
              ),
            ]
          )
        ]
      )
    );
  }
}