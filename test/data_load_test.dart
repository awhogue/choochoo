import 'package:test/test.dart';
import 'package:choochoo/model.dart';

void main() async {
  test('Test Data Load', () async {
    await Station.loadStations();
    await Stop.loadStops();
    print(Stop.byTrainNo('1883', Station.byStationName['HOHOKUS'].stopId));
  });

  test('Test DepartureVision', () async {
    await TrainStatus.refreshStatuses('HOHOKUS', true, 1000000000);
    print('${TrainStatus.statusesInOrder().length} statuses loaded.');
    for (var status in TrainStatus.statusesInOrder()) {
      print(status);
    }
  });
}