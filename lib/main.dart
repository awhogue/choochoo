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
    // Config.prodConfig(DefaultAssetBundle.of(context));
    Config.setOfflineDebugConfig();
    Config.forceScheduledNotification = true;
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
    _notifications = ChooChooNotifications(context);
  } 

  Future _loadData() async {
    ChooChooScheduler.stateInitialize(_notifications);
    await Datastore.loadDataFiles();
    if (Config.debug()) {
      await Datastore.clearWatchedStops();
      if (Config.primeCacheFromTestData) {
        await FileUtils.primeCacheFromTestData();
      }
      await Datastore.refreshStatuses(Config.hhkStation());

      if (Datastore.statuses.isEmpty) {
        print('Did not find any statuses to watch for debugging');
      } else {
        var nextDeparture = Datastore.statusesInOrder(Config.hhkStation())[0];
        print('Watching $nextDeparture for testing');
        await Datastore.addWatchedStop(WatchedStop(nextDeparture.stop, WatchedStop.weekdays));
      }
    } else {
      await Datastore.loadWatchedStops();
      await _addMyTrains();
      await Datastore.refreshStatuses(Config.hhkStation());
    }

    return true;
  }

  Future _addMyTrains() async {
    await Datastore.addWatchedStop(
      WatchedStop(Datastore.stopByTripId(Config.id803am, Config.hhkStation().stopId),
                  WatchedStop.weekdays)
    );
  }

  // Filter the statuses to only include the trains we're watching.
  List<TrainStatus> _watchedTrainStatuses() {
    print('watchedStops: ${Datastore.watchedStops}');
    List<TrainStatus> statuses = List<TrainStatus>();
    for (var status in Datastore.allStatuses()) {
      print('Considering $status');
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
                  if (Config.forceNotificationOnStartup && validStatuses.isNotEmpty) {
                    _notifications.trainStatusNotification(validStatuses[0]);
                  }
                }

                return ListView(
                  children: Datastore.statusesInOrder(Config.hhkStation()).map((ts) => TrainStatusCard(ts)).toList(),
                );
              }
            }
          }
        },
      ),
    );
  }
}
