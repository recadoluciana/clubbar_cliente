import '../utils/horario_brasil.dart';

class EventoDetalhe {
  final int id;
  final String titulo;
  final String classificacaoEtaria;
  final String descricao;
  final String politicaCancelamento;
  final String politicaLoja;
  final String orientacoesAcessoLoja;
  final String dataInicio;
  final String dataFim;
  final String local;
  final String endereco;
  final String numeroEndereco;
  final String bairro;
  final String bannerUrl;
  final String status;
  final String nomeLoja;
  final String nomeCidade;
  final String sgEstado;
  final String emailEvento;
  final String whatsappEvento;
  final String emailEstabelecimento;
  final String whatsappEstabelecimento;
  final List<AtracaoEventoDetalhe> atracoes;

  EventoDetalhe({
    required this.id,
    required this.titulo,
    this.classificacaoEtaria = 'Livre',
    required this.descricao,
    this.politicaCancelamento = '',
    this.politicaLoja = '',
    this.orientacoesAcessoLoja = '',
    required this.dataInicio,
    required this.dataFim,
    required this.local,
    required this.endereco,
    this.numeroEndereco = '',
    required this.bairro,
    required this.bannerUrl,
    required this.status,
    required this.nomeLoja,
    required this.nomeCidade,
    required this.sgEstado,
    this.emailEvento = '',
    this.whatsappEvento = '',
    this.emailEstabelecimento = '',
    this.whatsappEstabelecimento = '',
    required this.atracoes,
  });

  bool get jaIniciado {
    final inicio = HorarioBrasil.deTextoBrasil(dataInicio);
    if (inicio == null) return false;
    return !HorarioBrasil.agora().isBefore(inicio);
  }

  /// Endereço exibido ao cliente sem repetir bairro, cidade ou estado que já
  /// tenham vindo junto do logradouro em registros antigos.
  String get enderecoFormatado {
    final bairroLimpo = bairro.trim();
    final cidadeLimpa = nomeCidade.trim();
    final estadoLimpo = sgEstado.trim();
    final cidadeEstado = estadoLimpo.isEmpty
        ? cidadeLimpa
        : '${cidadeLimpa.isEmpty ? '' : '$cidadeLimpa - '}$estadoLimpo';

    final partes = endereco
        .split(',')
        .map((parte) => parte.trim())
        .where((parte) => parte.isNotEmpty)
        .where(
          (parte) =>
              !_mesmoTexto(parte, bairroLimpo) &&
              !_mesmoTexto(parte, cidadeLimpa) &&
              !_mesmoTexto(parte, cidadeEstado),
        )
        .toList();

    var numero = numeroEndereco.trim();
    if (numero.isEmpty && bairroLimpo.isNotEmpty && partes.isNotEmpty) {
      final ultimaParte = partes.last;
      final bairroEscapado = RegExp.escape(bairroLimpo);
      final encontrado = RegExp(
        '^(.+?)\\s+$bairroEscapado\$',
        caseSensitive: false,
      ).firstMatch(ultimaParte);
      final candidatoNumero = encontrado?.group(1)?.trim() ?? '';
      if (candidatoNumero.isNotEmpty &&
          RegExp(r'^\d+[\w/-]*$').hasMatch(candidatoNumero)) {
        numero = candidatoNumero;
        partes.removeLast();
      }
    }

    var logradouro = partes
        .join(', ')
        .replaceFirst(RegExp(r'^rua\s*:\s*', caseSensitive: false), 'Rua ');
    if (numero.isNotEmpty &&
        !RegExp(
          '(^|\\D)${RegExp.escape(numero)}(\\D|\$)',
        ).hasMatch(logradouro)) {
      logradouro = [
        logradouro,
        numero,
      ].where((parte) => parte.isNotEmpty).join(', ');
    }

    return [
      logradouro,
      bairroLimpo,
      cidadeEstado,
    ].where((parte) => parte.isNotEmpty).join(', ');
  }

  static bool _mesmoTexto(String primeiro, String segundo) {
    if (primeiro.isEmpty || segundo.isEmpty) return false;
    String normalizar(String valor) =>
        valor.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalizar(primeiro) == normalizar(segundo);
  }

  factory EventoDetalhe.fromJson(Map<String, dynamic> json) {
    final politicaLoja = Map<String, dynamic>.from(
      json['politica_loja'] as Map? ?? const {},
    );
    return EventoDetalhe(
      id: _toInt(json['evento_id'] ?? json['id'] ?? 0),
      titulo: (json['nmtituloevento'] ?? 'Evento').toString(),
      classificacaoEtaria: (json['classificacaoetaria'] ?? 'Livre').toString(),
      descricao: (json['dsdescevento'] ?? '').toString(),
      politicaCancelamento: (json['dspoliticacancelamento'] ?? '').toString(),
      politicaLoja: (politicaLoja['dspoliticaingresso'] ?? '').toString(),
      orientacoesAcessoLoja: (politicaLoja['dsorientacoesacesso'] ?? '')
          .toString(),
      dataInicio: (json['dtinicioevento'] ?? '').toString(),
      dataFim: (json['dtfimevento'] ?? '').toString(),
      local: (json['nmlocalevento'] ?? '').toString(),
      endereco: (json['dsendlocevento'] ?? '').toString(),
      numeroEndereco: (json['nrendlocevento'] ?? '').toString(),
      bairro: (json['dsbairroloja'] ?? '').toString(),
      bannerUrl: (json['urlbannerevento'] ?? '').toString().trim(),
      status: (json['statusevento'] ?? '').toString(),
      nomeLoja: (json['nmloja'] ?? '').toString(),
      nomeCidade: (json['nmcidade'] ?? '').toString(),
      sgEstado: (json['sgestado'] ?? '').toString(),
      emailEvento: (json['email_evento'] ?? '').toString(),
      whatsappEvento: (json['whatsapp_evento'] ?? '').toString(),
      emailEstabelecimento: (json['email_estabelecimento'] ?? '').toString(),
      whatsappEstabelecimento: (json['whatsapp_estabelecimento'] ?? '')
          .toString(),
      atracoes: (json['atracoes'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AtracaoEventoDetalhe.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }

  static int _toInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor.toString()) ?? 0;
  }
}

class AtracaoEventoDetalhe {
  final int id;
  final String nome;
  final String estilo;
  final String descricao;
  final String bannerUrl;
  final String inicio;
  final String fim;
  final List<String> estilos;

  const AtracaoEventoDetalhe({
    required this.id,
    required this.nome,
    required this.estilo,
    required this.descricao,
    required this.bannerUrl,
    required this.inicio,
    required this.fim,
    this.estilos = const [],
  });

  factory AtracaoEventoDetalhe.fromJson(Map<String, dynamic> json) {
    final estilos = (json['estilos'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => (item['nmestilomusical'] ?? '').toString().trim())
        .where((nome) => nome.isNotEmpty)
        .toList();
    final estiloLegado = (json['dsestilomusical'] ?? '').toString();
    return AtracaoEventoDetalhe(
      id: EventoDetalhe._toInt(json['atracao_id'] ?? 0),
      nome: (json['nmatracao'] ?? 'Atração').toString(),
      estilo: estilos.isNotEmpty ? estilos.join(', ') : estiloLegado,
      descricao: (json['dsatracao'] ?? '').toString(),
      bannerUrl: (json['urlbanneratracao'] ?? '').toString(),
      inicio: (json['dtinicioatracao'] ?? '').toString(),
      fim: (json['dtfimatracao'] ?? '').toString(),
      estilos: estilos.isNotEmpty
          ? estilos
          : estiloLegado
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(),
    );
  }
}
