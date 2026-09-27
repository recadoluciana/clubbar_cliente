import 'dart:convert';

import 'http_with_timeout.dart' as http;

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

  Future<List<EnderecoCep>> buscarPorEndereco({
    required String uf,
    required String cidade,
    required String logradouro,
  }) async {
    final estado = uf.trim().toUpperCase();
    final municipio = cidade.trim();
    final rua = logradouro.trim();
    if (estado.length != 2 || municipio.isEmpty || rua.length < 3) {
      throw Exception(
        'Informe UF, cidade e pelo menos três letras do endereço.',
      );
    }

    final uri = Uri.https('viacep.com.br', '/ws/$estado/$municipio/$rua/json/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Não foi possível localizar o CEP pelo endereço.');
    }
    final data = jsonDecode(response.body);
    if (data is! List) {
      throw Exception('Nenhum CEP foi encontrado para este endereço.');
    }
    return data
        .whereType<Map>()
        .map(
          (item) => EnderecoCep(
            cep: item['cep']?.toString() ?? '',
            logradouro: item['logradouro']?.toString().trim() ?? '',
            bairro: item['bairro']?.toString().trim() ?? '',
            cidade: item['localidade']?.toString().trim() ?? '',
            uf: item['uf']?.toString().trim().toUpperCase() ?? '',
          ),
        )
        .where((endereco) => endereco.cep.isNotEmpty)
        .toList();
  }
}
