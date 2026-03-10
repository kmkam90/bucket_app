import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation: triggers a browser download of the JSON file.
Future<bool> downloadJson(String jsonString, String filename) async {
  try {
    final bytes = utf8.encode(jsonString);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}

/// Web implementation: opens a file picker via hidden input element.
Future<String?> pickJsonFile() async {
  final completer = Completer<String?>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = '.json';

  input.addEventListener(
    'change',
    (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();
      reader.addEventListener(
        'load',
        (web.Event e) {
          final result = reader.result;
          if (result != null) {
            completer.complete((result as JSString).toDart);
          } else {
            completer.complete(null);
          }
        }.toJS,
      );
      reader.addEventListener(
        'error',
        (web.Event e) {
          completer.complete(null);
        }.toJS,
      );
      reader.readAsText(file);
    }.toJS,
  );

  input.click();
  return completer.future;
}
