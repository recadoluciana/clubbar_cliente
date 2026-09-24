import 'package:web/web.dart' as web;

void limparUrlWeb() {
  Future.delayed(const Duration(milliseconds: 300), () {
    web.window.history.replaceState(null, 'Clubbar', '/');
  });
}
