import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void initDatabasePlatform() {
  databaseFactory = databaseFactoryFfiWeb;
}
