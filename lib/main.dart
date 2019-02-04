import 'package:flutter/material.dart';
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
  static const _testMode = false;

  ChooChooNotifications _notifications;
  
  _ChooChooHomeState() {
    _notifications = ChooChooNotifications(context);
  } 

  Future _loadData() async {
    ChooChooScheduler.stateInitialize(_notifications, DefaultAssetBundle.of(context));
    await Datastore.loadDataFiles(DefaultAssetBundle.of(context));
    await Datastore.loadWatchedStops();
    return await _getTrainStatuses();
  }

  Future _getTrainStatuses() async {
    var bundle = DefaultAssetBundle.of(context);
    var hhkStation = Datastore.stationByStationName['HOHOKUS'];
    if (_testMode) {
      print('TEST MODE');
      Datastore.clearWatchedStops();
      var filename = FileUtils.normalizeForFilename(hhkStation.stationName);
      var cacheHtml = await FileUtils.loadFile('dv_cache/$filename.htm', bundle);
      print('Got ${cacheHtml.length} bytes of cached data from $filename');
      var cacheFile = await FileUtils.getCacheFile(hhkStation.stationName);
      cacheFile.writeAsStringSync(cacheHtml);
      await Datastore.refreshStatuses(
        hhkStation, DefaultAssetBundle.of(context), 
        true, false, 10000000);

      // For testing, just watch the next arrival.
      var nextDeparture = Datastore.statusesInOrder(hhkStation)[0];
      print('Watching $nextDeparture for testing');
      Datastore.addWatchedStop(WatchedStop(nextDeparture.stop, WatchedStop.weekdays));
    } else {
      // TODO: Let user add these instead.
      await _setUpDummyWatchedStops();
      await Datastore.refreshStatuses(hhkStation, DefaultAssetBundle.of(context));

    }
    return true;
  }

  Future _setUpDummyWatchedStops() async {
    Datastore.clearWatchedStops();
    // 8:03am from HOHOKUS
    await Datastore.addWatchedStop(
      WatchedStop(Datastore.stopByTripId(1162, Datastore.stationByStationName['HOHOKUS'].stopId),
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
                if (_testMode) {
                  List<TrainStatus> validStatuses = _watchedTrainStatuses();
                  if (validStatuses.isNotEmpty) {
                    _notifications.trainStatusNotification(validStatuses[0]);
                  }
                }

                return ListView(
                  children: Datastore.statusesInOrder(Datastore.stationByStationName['HOHOKUS']).map((ts) => TrainStatusCard(ts)).toList(),
                );
              }
            }
          }
        },
      ),
    );
  }
}
