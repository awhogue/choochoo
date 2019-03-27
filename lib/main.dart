import 'dart:async';
import 'package:flutter/material.dart';
import 'config.dart';
import 'datastore.dart';
import 'file_utils.dart';
import 'model.dart';
import 'notifications.dart';
import 'scheduler.dart';
import 'train_status_card.dart';

void main() async {
  await ChooChooScheduler.appInitialize();
  runApp(ChooChooApp());
}

class ChooChooApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Config.setBundle(DefaultAssetBundle.of(context));
    //Config.setOfflineDebugConfig();
    print(Config.configString());

    return MaterialApp(
      title: 'Choo Choo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChooChooHome(title: 'Choo Choo!'),
    );
  }
}

class ChooChooHome extends StatefulWidget {
  ChooChooHome({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _ChooChooHomeState createState() => _ChooChooHomeState();
}

class _ChooChooHomeState extends State<ChooChooHome> {
  ChooChooNotifications _notifications;
  
  _ChooChooHomeState() {
    _notifications = ChooChooNotifications();
  } 

  Future _loadData() async {
    print("_loadData()");
    ChooChooScheduler.stateInitialize(_notifications);
    await Datastore.loadData();
    if (Config.debug()) {
      if (Config.primeCacheFromTestData) {
        await FileUtils.primeCacheFromTestData();
        await Datastore.refreshStatuses(Config.hhkStation());
      }
    } else {
      await Datastore.clearWatchedStops(); // For debugging.
      await Datastore.loadWatchedStops();
      await _addMyTrains();
      await Datastore.refreshStatuses(Config.hhkStation());
      await Datastore.refreshStatuses(Config.hobStation());
    }

    var nextDeparture = await Datastore.nextWatchedDeparture();
    return nextDeparture;
  }

  Future _addMyTrains() async {
    await Datastore.addWatchedStops(
      Config.myHHKTrains.values.map(
        (id) => WatchedStop(Datastore.stopByTripId(id, Config.hhkStation().stopId), Stop.everyday)).toList(),
        false);
    await Datastore.addWatchedStops(
      Config.myHOBTrains.values.map(
        (id) => WatchedStop(Datastore.stopByTripId(id, Config.hobStation().stopId), Stop.everyday)).toList(),
        true);
  }

  // Filter the statuses to only include the trains we're watching.
  List<TrainStatus> _watchedTrainStatuses() {
    print('watchedStops: ${Datastore.watchedStops}');
    List<TrainStatus> statuses = List<TrainStatus>();
    for (var status in Datastore.allStatuses()) {
      if (Datastore.watchedStops.containsKey(status.stop.id())) {
        statuses.add(status);
      }
    }
    return statuses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder(
        future: _loadData(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none: {
              print('ConnectionState.none??');
              return Center(child: CircularProgressIndicator());
            }
            case ConnectionState.active:
            case ConnectionState.waiting: {
              print('no data yet');
              return Center(child: CircularProgressIndicator());
            }
            case ConnectionState.done: {
              if (snapshot.hasError) {
                print('Snapshot error: ${snapshot.error}');
                return Center(child: Text('Error retrieving train data: ${snapshot.error}'));
              } else if (snapshot.data == null) {
                print('data is null');
                return Center(child: Text('Set up some trains to watch!'));
              } else {
                if (Config.debug()) {
                  List<TrainStatus> validStatuses = _watchedTrainStatuses();
                  print('Found ${validStatuses.length} validStatuses');
                  if (Config.forceNotificationOnStartup && validStatuses.isNotEmpty) {
                    _notifications.trainStatusNotification(validStatuses[0]);
                  }
                }

                var nextDeparture = snapshot.data;
                if (null == nextDeparture) {
                  print('snapshot.data is null');
                  return Center(child: Text('Set up some trains to watch!'));
                }

                var displayStatuses = Datastore.statusesInOrder(
                  Config.hhkStation(), 
                  nextDeparture.stop.train.destinationStation);
                return ListView(
                  children: displayStatuses.map((ts) => TrainStatusCard(ts)).toList(),
                );
              }
            }
          }
        },
      ),
    );
  }
}
