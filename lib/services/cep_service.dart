import 'dart:convert';

import 'package:http/http.dart' as http;

class EnderecoCep {
  final String cep;
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;

  const EnderecoCep({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });
}

class CepService {
  Future<EnderecoCep> buscar(String cep) async {
    final numeros = cep.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeros.length != 8) {
      throw Exception('Informe um CEP válido com 8 dígitos.');
    }
    final response = await http.get(
      Uri.parse('https://viacep.com.br/ws/$numeros/json/'),
    );
    if (response.statusCode != 200) {
      throw Exception('Não foi possível consultar o CEP.');
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['erro'] == true) {
      throw Exception('CEP não encontrado.');
    }
    return EnderecoCep(
      cep: data['cep']?.toString() ?? numeros,
      logradouro: data['logradouro']?.toString().trim() ?? '',
      bairro: data['bairro']?.toString().trim() ?? '',
      cidade: data['localidade']?.toString().trim() ?? '',
      uf: data['uf']?.toString().trim().toUpperCase() ?? '',
    );
  }
}
