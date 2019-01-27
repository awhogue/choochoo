import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:test/test.dart';
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
    await Station.loadStations(bundle);
    await Stop.loadStops(bundle);
    print(Stop.byTrainNo('1883', Station.byStationName['HOHOKUS'].stopId));
  });

  test('Test DepartureVision', () async {
    await TrainStatus.refreshStatuses('HOHOKUS', bundle, true, false, 1000000000);
    print('${TrainStatus.statusesInOrder().length} statuses loaded.');
    for (var status in TrainStatus.statusesInOrder()) {
      print(status);
    }
  });
}