// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void limparUrlWeb() {
  Future.delayed(const Duration(milliseconds: 300), () {
    html.window.history.replaceState(null, 'Clubbar', '/');
  });
}
