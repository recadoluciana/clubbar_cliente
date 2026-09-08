import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../services/auth_storage.dart';
import '../../widgets/app_version_text.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';

class AtendimentoCoraScreen extends StatefulWidget {
  const AtendimentoCoraScreen({super.key});

  @override
  State<AtendimentoCoraScreen> createState() => _AtendimentoCoraScreenState();
}

class _AtendimentoCoraScreenState extends State<AtendimentoCoraScreen> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  List<_Mensagem> _mensagens = [];
  List<_Duvida> _duvidas = [];
  bool _carregando = true;
  bool _enviando = false;
  bool _apiOnline = false;
  bool _bancoOnline = false;

  bool get _dev =>
      AppConfig.isDev ||
      AppConfig.apiBaseUrl.contains('desenvolvimento') ||
      AppConfig.apiBaseUrl.contains('localhost');

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthStorage().obterToken();
    return {
      'Content-Type': 'application/json',
      if (token?.isNotEmpty == true) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _carregar() async {
    await Future.wait([
      _consultarAmbiente(),
      _buscarDuvidas(),
      _buscarMensagens(),
    ]);
    if (mounted) setState(() => _carregando = false);
    _rolarAteFinal();
  }

  Future<void> _buscarDuvidas() async {
    try {
      final resposta = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/cora/duvidas'),
      );
      if (resposta.statusCode != 200) return;
      final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
      if (mounted) {
        setState(
          () => _duvidas = lista
              .map((e) => _Duvida.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _buscarMensagens() async {
    try {
      final resposta = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/cora/mensagens'),
        headers: await _headers(),
      );
      if (resposta.statusCode != 200) return;
      final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List;
      if (mounted) {
        setState(
          () => _mensagens = lista
              .map((e) => _Mensagem.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _consultarAmbiente() async {
    try {
      final resposta = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      final dados = resposta.statusCode == 200
          ? jsonDecode(resposta.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _apiOnline = resposta.statusCode == 200 && dados['api'] == 'online';
        _bancoOnline = dados['database'] == 'online';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiOnline = false;
        _bancoOnline = false;
      });
    }
  }

  Future<void> _enviar() async {
    final mensagem = _texto.text.trim();
    if (mensagem.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final resposta = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/cora/mensagens'),
        headers: await _headers(),
        body: jsonEncode({'mensagem': mensagem}),
      );
      if (resposta.statusCode == 401 || resposta.statusCode == 403) {
        throw const _SessaoCoraException();
      }
      if (resposta.statusCode != 201) throw Exception();
      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      final novas = (dados['mensagens'] as List).map(
        (e) => _Mensagem.fromJson(e as Map<String, dynamic>),
      );
      if (!mounted) return;
      setState(() {
        _texto.clear();
        _mensagens.addAll(novas);
      });
      _rolarAteFinal();
    } on _SessaoCoraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sua sessão expirou. Entre novamente para falar com a Cora.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível enviar a mensagem. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _rolarAteFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _statusAcesso(String nome, bool online) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(nome, style: const TextStyle())),
        if (online) ...[
          const Icon(Icons.circle, size: 10, color: Colors.green),
          const SizedBox(width: 6),
          Text('Online', style: TextStyle(color: Colors.green.shade800)),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Offline',
              style: TextStyle(color: Colors.red.shade800, fontSize: 11),
            ),
          ),
      ],
    ),
  );

  BoxDecoration _decoracaoCard() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.grey.shade200),
  );

  Widget _apresentacaoCora() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: _decoracaoCard(),
    child: Row(
      children: [
        Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Image.asset('assets/images/corujao.png', fit: BoxFit.contain),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Olá, sou Coralina Corrêa Murad, mas pode me chamar de Cora.',
            style: TextStyle(fontSize: 16, height: 1.35),
          ),
        ),
      ],
    ),
  );

  Widget _faq() => Container(
    decoration: _decoracaoCard(),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.help_outline_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text('Dúvidas frequentes', style: TextStyle(fontSize: 17)),
            ],
          ),
        ),
        const ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Text('Qual a versão do Clubbar?'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppVersionText(style: TextStyle()),
            ),
          ],
        ),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: const Text('Como está meu acesso ao aplicativo?'),
          children: [
            _statusAcesso('API do Clubbar', _apiOnline),
            _statusAcesso('Banco de dados', _bancoOnline),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ambiente do banco: ${_dev ? 'Development' : 'Production'}',
              ),
            ),
          ],
        ),
        ..._duvidas.map(
          (duvida) => ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Text(duvida.pergunta),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(duvida.resposta),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _avatarCora({double tamanho = 34}) => Container(
    width: tamanho,
    height: tamanho,
    padding: EdgeInsets.all(tamanho * .1),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.amber.shade300),
    ),
    child: Image.asset('assets/images/corujao.png', fit: BoxFit.contain),
  );

  Widget _bolha(_Mensagem item) => Align(
    alignment: item.cliente ? Alignment.centerRight : Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!item.cliente) ...[
          _avatarCora(tamanho: 34),
          const SizedBox(width: 7),
        ],
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 310),
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
            decoration: BoxDecoration(
              color: item.cliente ? const Color(0xFFD9FDD3) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 3),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.cliente ? 'Você' : 'Cora',
                  style: TextStyle(
                    color: item.cliente
                        ? Colors.green.shade800
                        : Colors.blue.shade700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(item.texto),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${item.horario.hour.toString().padLeft(2, '0')}:${item.horario.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _conversa() => Container(
    height: 390,
    decoration: BoxDecoration(
      color: const Color(0xFFEFEAE2),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              _avatarCora(tamanho: 38),
              const SizedBox(width: 10),
              const Text('Conversa com a Cora'),
            ],
          ),
        ),
        Expanded(
          child: _mensagens.isEmpty
              ? const Center(
                  child: Text('Envie uma mensagem para iniciar a conversa.'),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _mensagens.length,
                  itemBuilder: (_, i) => _bolha(_mensagens[i]),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _texto,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviar(),
                  decoration: const InputDecoration(
                    hintText: 'Digite sua mensagem...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Enviar',
                onPressed: _enviando ? null : _enviar,
                style: IconButton.styleFrom(backgroundColor: Colors.green),
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F6F6),
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        const ClubbarPageHeader(
          titulo: 'Cora responde',
          subtitulo: 'Dúvidas frequentes e atendimento',
          mostrarAvatar: false,
          corTitulo: Colors.blue,
          pesoTitulo: FontWeight.normal,
          pesoSubtitulo: FontWeight.normal,
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _apresentacaoCora(),
                    const SizedBox(height: 14),
                    _faq(),
                    const SizedBox(height: 14),
                    _conversa(),
                  ],
                ),
        ),
      ],
    ),
  );
}

class _Mensagem {
  final String texto;
  final bool cliente;
  final DateTime horario;

  const _Mensagem({
    required this.texto,
    required this.cliente,
    required this.horario,
  });

  factory _Mensagem.fromJson(Map<String, dynamic> json) => _Mensagem(
    texto: json['mensagem']?.toString() ?? '',
    cliente: json['origem'] == 'CLIENTE',
    horario:
        DateTime.tryParse(json['dtcriacao']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

class _Duvida {
  final String pergunta;
  final String resposta;

  const _Duvida({required this.pergunta, required this.resposta});

  factory _Duvida.fromJson(Map<String, dynamic> json) => _Duvida(
    pergunta: json['pergunta']?.toString() ?? '',
    resposta: json['resposta']?.toString() ?? '',
  );
}

class _SessaoCoraException implements Exception {
  const _SessaoCoraException();
}
