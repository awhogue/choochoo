import 'dart:io';
import 'package:test/test.dart';
import 'package:choochoo/model.dart';

void main() async {
  test('Test Data Load', () async {
    await Station.loadStations();
    await Stop.loadStops();
    print(Stop.byTrainNo('1883', Station.byStationName['HOHOKUS'].stopId));
  });

  final fetchAndCacheHtml = false;
  final departureVisionFilename = 'njtransit_data/sample_departure.htm';
  test('Test DepartureVision', () async {
    await Station.loadStations();
    var station = Station.byStationName['HOHOKUS'];
    if (fetchAndCacheHtml) {
      String html = await TrainStatus.fetchDepartureVision(station);
      new File(departureVisionFilename).writeAsStringSync(html);
      print('Wrote ${html.length} bytes to $fetchAndCacheHtml');
    }
    print('Reading cached html from $departureVisionFilename');
    var html = new File(departureVisionFilename).readAsStringSync();
    print('Read ${html.length} bytes from $departureVisionFilename');
    await TrainStatus.parseDepartureVision(html, station);
  });
}