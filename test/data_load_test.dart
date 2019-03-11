import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:test/test.dart';
import 'package:choochoo/config.dart';
import 'package:choochoo/datastore.dart';
import 'package:choochoo/model.dart';

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData.view(Uint8List.fromList(new File(key).readAsBytesSync()).buffer);
  }
}

void main() async {
  AssetBundle bundle = new TestAssetBundle();
  final directory = 'assets/njtransit';
  
  setUpAll(() async {
    Config.setBundle(bundle);
    Config.setUnitTestConfig();
    
    const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall methodCall) async {
      // If we're getting the apps documents directory, return the path to the
      // temp directory on our test environment instead.
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return directory;
      }
      return null;
    });
  });

  test('Test Data Load', () async {
    await Datastore.loadDataFiles();
    print(Datastore.stopByTrainNo('1883', Config.hhkStation().stopId));
  });

  test('Test DepartureVision', () async {
    await Datastore.loadDataFiles();
    var station = Config.hhkStation();
    await Datastore.refreshStatuses(station);
    for (var status in Datastore.statusesInOrder(station)) {
      print(status);
    }
  });

  test('Test save and load WatchedStops', () async {
    await Datastore.loadDataFiles();
    WatchedStop ws = WatchedStop(
      Datastore.stopByTrainNo('1156', Config.hhkStation().stopId),
      Stop.everyday);

    String json = Datastore.watchedStopsToJson([ws]);
    List<WatchedStop> watchedStops = Datastore.loadWatchedStopsFromJson(json);

    expect(watchedStops.length, equals(1));
    WatchedStop restored = watchedStops[0];
    print('Comparing:\n$ws\n$restored');

    expect(restored.stop.id(), equals(ws.stop.id()));
    expect(restored.days, equals(ws.days));
  });
}