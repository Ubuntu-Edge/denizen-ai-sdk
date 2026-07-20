import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.openInMemory();
  
  // Try using db.ensureExtensionLoaded if it exists
  try {
    // We'll just look at the error to see if the method exists
    print((db as dynamic).loadExtension('fake'));
  } catch(e) {
    print('Error: \$e');
  }
}
