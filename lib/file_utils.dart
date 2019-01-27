// Utilities for working with data files.
import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class FileUtils {
  static final _csvConverter = new CsvToListConverter(eol: '\n');

  static Future csvFileToArray(String filename, AssetBundle bundle) async {
    print('Loading $filename...');
    var content = await loadFile(filename, bundle);
    var rows = _csvConverter.convert(content);
    print('loaded ${rows.length} rows from $filename');
    return rows;
  }

  static Future<String> loadFile(String filename, AssetBundle bundle) async {
    return await bundle.loadString(path.join('assets', 'njtransit', filename));
  }
}