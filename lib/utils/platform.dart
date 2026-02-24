import 'dart:io';

bool isDesktopPlatform() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

bool isMobilePlatform() {
  return Platform.isAndroid || Platform.isIOS;
}
