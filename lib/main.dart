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
  List<TrainStatus> _statuses = List();

  Future<List<TrainStatus>> _getTrainStatuses() async {
    if (_testMode) {
      print('TEST MODE');
      var bundle = DefaultAssetBundle.of(context);
      var cacheHtml = await FileUtils.loadFile('dv_cache/hohokus.htm', bundle);
      print('Got ${cacheHtml.length} bytes of cached data');
      var cacheFile = await FileUtils.getCacheFile('HOHOKUS');
      cacheFile.writeAsStringSync(cacheHtml);
      await Datastore.refreshStatuses('HOHOKUS', DefaultAssetBundle.of(context), true, false, 10000000);
    } else {
      // TODO: Replace 'HOHOKUS' with a list of stations that this user cares about.
      await Datastore.refreshStatuses('HOHOKUS', DefaultAssetBundle.of(context), true, true, 1);
    }
    return Datastore.statusesInOrder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder(
        future: _getTrainStatuses(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasError) print('Snapshot error: ${snapshot.error}');
          if (!snapshot.hasData) {
            print('no data yet');
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.data == null) {
            print('data is null');
            return Center(child: Text('Set up some trains to watch!'));
          } else {
            print('got data!');
            _statuses = snapshot.data;
            return ListView(
              children: _statuses.map((ts) => TrainStatusCard(ts)).toList(),
            );
          }
        },
      ),
    );
  }
}
