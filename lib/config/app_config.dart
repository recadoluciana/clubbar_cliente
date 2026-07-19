class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.clubbar.com.br',
  );

  static const String appWebUrl = String.fromEnvironment(
    'APP_WEB_URL',
    defaultValue: 'https://app.clubbar.com.br',
  );

  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://clubbar.com.br',
  );

  static const String checkoutCartaoUrl =
      '$apiBaseUrl/static/checkout_cartao.html';
}
