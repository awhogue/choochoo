// Utilities for working with data files.
import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class FileUtils {
  static final _csvConverter = new CsvToListConverter(eol: '\n');

  static Future csvFileToArray(String filename, AssetBundle bundle) async {
    var content = await loadFile(filename, bundle);
    var rows = _csvConverter.convert(content);
    print('loaded ${rows.length} rows from $filename');
    return rows;
  }

  static Future<String> loadFile(String filename, AssetBundle bundle) async {
    var pathStr = path.join('assets', 'njtransit', filename);
    print('loadFile($pathStr)');
    return await bundle.loadString(pathStr);
  }

  // Reformat the station name to make it usable for a filename.
  static String _normalizeForFilename(String stationName) {
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
    var filename = _normalizeForFilename(stationName);
    return new File(path.join(cacheDirectory.path, '$filename.htm'));
  }

}