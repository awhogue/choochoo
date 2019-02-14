// Utilities for working with data files.
import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'config.dart';
import 'datastore.dart';

class FileUtils {
  static final _csvConverter = new CsvToListConverter(eol: '\n');

  static Future csvFileToArray(String filename) async {
    var content = await loadFile(filename);
    var rows = _csvConverter.convert(content);
    print('loaded ${rows.length} rows from $filename');
    return rows;
  }

  static Future<String> loadFile(String filename) async {
    var pathStr = path.join('assets', 'njtransit', filename);
    print('loadFile($pathStr)');
    return await Config.bundle.loadString(pathStr);
  }

  // Reformat the station name to make it usable for a filename.
  static String normalizeForFilename(String stationName) {
    return stationName.replaceAll(r'\W', '_').toLowerCase();
  }

  // Gets the File object for the cache for the given station. If the cache directory doesn't 
  // yet exist, creates it.
  static Future<File> getCacheFile(String stationName) async {
    // Get the working directory for permanent storage of files for the app.
    final appDirectory = await getApplicationDocumentsDirectory();
    final cacheDirectory = new Directory(path.join(appDirectory.path, 'dv_cache'));
    if (!cacheDirectory.existsSync()) {
      cacheDirectory.createSync();
    }
    var filename = normalizeForFilename(stationName);
    return new File(path.join(cacheDirectory.path, '$filename.htm'));
  }

  // Use the cached HTML from unit testing to prime the DepartureVision cache for the running app.
  // (Useful either when we want stable train data to play with, or when there is no internet 
  // connection to retrieve fresh data.)
  static primeCacheFromTestData() async {
    print('Priming cache file from test data');
    var filename = normalizeForFilename(Config.hhkStation().stationName);
    var cacheHtml = await FileUtils.loadFile('dv_cache/$filename.htm');
    print('Got ${cacheHtml.length} bytes of cached data from $filename');
    var cacheFile = await FileUtils.getCacheFile(Config.hhkStation().stationName);
    cacheFile.writeAsStringSync(cacheHtml);
    await Datastore.refreshStatuses(Config.hhkStation());
  }

}