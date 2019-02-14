// Visual representation of one train stop at a station with a status 
// (scheduled time, actual time, canceled, etc.).

import 'package:flutter/material.dart';
import 'display_utils.dart';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Train #${status.stop.train.trainNo}',
                  style: Theme.of(context).textTheme.title,
                )
              ),
              Text(
                DisplayUtils.timeString(status.stop.scheduledDepartureTime),
                style: Theme.of(context).textTheme.title,
              )
            ]
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  DisplayUtils.shortStatus(status),
                  style: Theme.of(context).textTheme.title,
                ),
              ),
              Text(
                DisplayUtils.timeStatus(status),
                style: Theme.of(context).textTheme.title,
              ),
            ],
          ),
        ],
      ),
    );
  }
}