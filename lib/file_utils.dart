// Utilities for working with data files.
import 'dart:io';
import 'package:csv/csv.dart';

class FileUtils {
  static final _csvConverter = new CsvToListConverter(eol: '\n');

  static csvFileToArray(String filename) {
    print('Loading $filename...');
    var content = new File(filename).readAsStringSync();
    var rows = _csvConverter.convert(content);
    print('loaded ${rows.length} rows from $filename');
    return rows;
  }

}