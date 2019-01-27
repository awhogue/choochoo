import 'package:flutter/material.dart';
import 'train_status_card.dart';
import 'model.dart';

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
      await TrainStatus.refreshStatuses('HOHOKUS', DefaultAssetBundle.of(context), true, false, 10000000);
    } else {
      // TODO: Replace 'HOHOKUS' with a list of stations that this user cares about.
      await TrainStatus.refreshStatuses('HOHOKUS', DefaultAssetBundle.of(context), true, true, 5);
    }
    return TrainStatus.statusesInOrder();
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
