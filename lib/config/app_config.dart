import 'package:flutter/services.dart';

class AppConfig {
  static const String _apiDesenvolvimento =
      'https://apiclubbar-desenvolvimento.up.railway.app';
  static const String _apiProducao = 'https://api.clubbar.com.br';

  static String get ambiente {
    switch (appFlavor) {
      case 'dev':
        return 'DESENVOLVIMENTO';
      case 'prod':
        return 'PRODUCAO';
      default:
        return 'NAO DEFINIDO';
    }
  }

  static bool get isDev => appFlavor == 'dev';
  static bool get isProd => appFlavor == 'prod';

  static String get apiBaseUrl {
    const urlInformada = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    if (urlInformada.trim().isNotEmpty) {
      return _removerBarraFinal(urlInformada.trim());
    }

    switch (appFlavor) {
      case 'dev':
        return _apiDesenvolvimento;
      case 'prod':
        return _apiProducao;
      default:
        // Mantem producao como fallback em plataformas sem flavor, como Web.
        return _apiProducao;
    }
  }

  static const String appWebUrl = String.fromEnvironment(
    'APP_WEB_URL',
    defaultValue: 'https://app.clubbar.com.br',
  );

  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://clubbar.com.br',
  );

  static String get checkoutCartaoUrl =>
      '$apiBaseUrl/static/checkout_cartao.html';

  static String _removerBarraFinal(String valor) {
    var resultado = valor;
    while (resultado.endsWith('/')) {
      resultado = resultado.substring(0, resultado.length - 1);
    }
    return resultado;
  }
}
