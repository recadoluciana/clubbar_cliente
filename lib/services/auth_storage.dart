import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _keyToken = 'access_token';
  static const _keyClienteId = 'cliente_id';
  static const _keyNomeCliente = 'nmcliente';

  Future<void> salvarLogin({
    required String token,
    required int clienteId,
    required String nomeCliente,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyToken, token);
    await prefs.setInt(_keyClienteId, clienteId);
    await prefs.setString(_keyNomeCliente, nomeCliente);
  }

  Future<String?> obterToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<int?> obterClienteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyClienteId);
  }

  Future<String?> obterNmcliente() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNomeCliente);
  }

  Future<bool> estaLogado() async {
    final token = await obterToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> limparToken() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyToken);
    await prefs.remove(_keyClienteId);
    await prefs.remove(_keyNomeCliente);
  }
}
