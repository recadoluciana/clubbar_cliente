import '../../config/app_config.dart';

class Loja {
  final int id;
  final int organizacaoId;
  final String nome;
  final String endereco;
  final String bairro;
  final String cidade;
  final String horario;
  final String imagemUrl;
  final String instagram;
  final double vrtaxaprod;
  final double vrtaxaing;

  Loja({
    required this.id,
    required this.organizacaoId,
    required this.nome,
    required this.endereco,
    required this.bairro,
    required this.cidade,
    required this.horario,
    required this.imagemUrl,
    required this.instagram,
    required this.vrtaxaprod,
    required this.vrtaxaing,
  });

  static const String baseUrl =
      AppConfig.apiBaseUrl; // Use the apiBaseUrl from AppConfig

  static String buildUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return "$baseUrl$path";
  }

  factory Loja.fromJson(Map<String, dynamic> json) {
    final path = (json['urllogoloja'] ?? '').toString();

    return Loja(
      id: _toInt(json['loja_id'] ?? 0),
      organizacaoId: _toInt(json['organizacao_id'] ?? 0),
      nome: (json['nmloja'] ?? '').toString(),
      endereco: (json['endloja'] ?? '').toString(),
      bairro: (json['dsbairroloja'] ?? '').toString(),
      cidade: (json['nmcidade'] ?? '').toString(),
      horario: (json['dshorarioloja'] ?? '').toString(),
      imagemUrl: buildUrl(path),
      instagram: (json['dsinstaloja'] ?? '').toString(),
      vrtaxaprod: double.tryParse(json['vrtaxaprod']?.toString() ?? '0') ?? 0,
      vrtaxaing: double.tryParse(json['vrtaxaing']?.toString() ?? '0') ?? 0,
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}
