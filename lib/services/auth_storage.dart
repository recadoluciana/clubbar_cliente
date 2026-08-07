import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _secureStorage = FlutterSecureStorage();
  static const _keyToken = 'access_token';
  static const _keyClienteId = 'cliente_id';
  static const _keyNomeCliente = 'nmcliente';

  Future<void> salvarLogin({
    required String token,
    required int clienteId,
    required String nomeCliente,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      await prefs.setString(_keyToken, token);
    } else {
      await _secureStorage.write(key: _keyToken, value: token);
      await prefs.remove(_keyToken);
    }
    await prefs.setInt(_keyClienteId, clienteId);
    await prefs.setString(_keyNomeCliente, nomeCliente);
  }

  Future<String?> obterToken() async {
    if (!kIsWeb) {
      final tokenSeguro = await _secureStorage.read(key: _keyToken);
      if (tokenSeguro?.isNotEmpty == true) return tokenSeguro;

      // Migra automaticamente sessões criadas antes do armazenamento seguro.
      final prefs = await SharedPreferences.getInstance();
      final tokenLegado = prefs.getString(_keyToken);
      if (tokenLegado?.isNotEmpty == true) {
        await _secureStorage.write(key: _keyToken, value: tokenLegado);
        await prefs.remove(_keyToken);
      }
      return tokenLegado;
    }
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
    if (!kIsWeb) {
      await _secureStorage.delete(key: _keyToken);
    }
    await prefs.remove(_keyClienteId);
    await prefs.remove(_keyNomeCliente);
  }
}
