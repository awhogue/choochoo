import 'package:test/test.dart';
import 'package:choochoo/model.dart';

void main() async {
  test('Test Data Load', () async {
    await Station.loadStations();
    await Stop.loadStops();
    print(Stop.byTrainNo('1883', Station.byStationName['HOHOKUS'].stopId));
  });

  test('Test DepartureVision', () async {
    // TODO: mock out the departurevision
    await TrainStatus.refreshStatuses('HOHOKUS');
  });
}