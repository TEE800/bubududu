import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<void> openBytes(Uint8List bytes, String name, String mime) async {
  final dir = await getTemporaryDirectory();
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${dir.path}/$safe');
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFilex.open(file.path, type: mime);
  if (result.type == ResultType.noAppToOpen) {
    throw Exception('Keine App zum Öffnen gefunden.');
  }
  if (result.type != ResultType.done) throw Exception(result.message);
}
