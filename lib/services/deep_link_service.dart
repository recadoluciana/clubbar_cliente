import 'dart:async';

import 'package:app_links/app_links.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;

  Future<Uri?> getInitialLink() async {
    return await _appLinks.getInitialLink();
  }

  void start(void Function(Uri uri) onLink) {
    _subscription?.cancel();

    _subscription = _appLinks.uriLinkStream.listen(onLink, onError: (_) {});
  }

  void dispose() {
    _subscription?.cancel();
  }
}
