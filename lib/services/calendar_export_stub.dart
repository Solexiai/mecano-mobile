import 'package:flutter/services.dart';

Future<bool> saveCalendarExport(String content) async {
  await Clipboard.setData(ClipboardData(text: content));
  return false;
}
