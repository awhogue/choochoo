import 'package:flutter/material.dart';
import 'train_status_card.dart';
import 'file_utils.dart';
import 'model.dart';
import 'datastore.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
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
  static const _testMode = true;

  Future _loadData() async {
    await Datastore.loadDataFiles(DefaultAssetBundle.of(context));
    await Datastore.loadWatchedStops();
    return await _getTrainStatuses();
  }

  Future _getTrainStatuses() async {
    var bundle = DefaultAssetBundle.of(context);
    if (_testMode) {
      print('TEST MODE');
      Datastore.clearWatchedStops();
      var watchedStation = Datastore.stationByStationName['HOHOKUS'];
      var filename = FileUtils.normalizeForFilename(watchedStation.stationName);
      var cacheHtml = await FileUtils.loadFile('dv_cache/$filename.htm', bundle);
      print('Got ${cacheHtml.length} bytes of cached data from $filename');
      var cacheFile = await FileUtils.getCacheFile(watchedStation.stationName);
      cacheFile.writeAsStringSync(cacheHtml);
      await Datastore.refreshStatuses(
        watchedStation.stationName, DefaultAssetBundle.of(context), 
        false, false, 10000000);

      // For testing, just watch the next arrival.
      var nextDeparture = Datastore.statusesInOrder()[0];
      print('Watching $nextDeparture for testing');
      Datastore.addWatchedStop(WatchedStop(nextDeparture.stop, WatchedStop.weekdays));
    } else {
      await _setUpDummyWatchedTrains();
      var watchedStations = Datastore.watchedStops.values.map((ws) => ws.stop.departureStation).toList();
      for (var watchedStation in watchedStations) {
        await Datastore.refreshStatuses(
          watchedStation.stationName, DefaultAssetBundle.of(context), 
          true, true, 1);
      }
    }
    return true;
  }

  Future _setUpDummyWatchedTrains() async {
    // 8:03am from HOHOKUS
    await Datastore.addWatchedStop(
      WatchedStop(Datastore.stopByTripId(1162, Datastore.stationByStationName['HOHOKUS'].stopId),
                  WatchedStop.weekdays)
    );
  }

  // Filter the statuses to only include the trains we're watching.
  List<TrainStatus> _watchedTrainStatuses() {
    List<TrainStatus> statuses = List<TrainStatus>();
    for (var key in Datastore.watchedStops.keys) {
      if (Datastore.statuses.containsKey(key)) {
        statuses.add(Datastore.statuses[key]);
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
                print('got data!');

                List<TrainStatus> validStatuses = _watchedTrainStatuses();
                return ListView(
                  children: validStatuses.map((ts) => TrainStatusCard(ts)).toList(),
                );
              }
            }
          }
        },
      ),
    );
  }
}
