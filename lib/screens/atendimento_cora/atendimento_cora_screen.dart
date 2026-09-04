import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/perfil_page_header.dart';

class AtendimentoCoraScreen extends StatefulWidget {
  const AtendimentoCoraScreen({super.key});

  @override
  State<AtendimentoCoraScreen> createState() => _AtendimentoCoraScreenState();
}

class _AtendimentoCoraScreenState extends State<AtendimentoCoraScreen> {
  final _mensagemController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_MensagemCora> _mensagens = [];

  bool _apiOnline = false;
  bool _bancoOnline = false;
  String _nomeCliente = 'Cliente';

  bool get _ambienteDev =>
      AppConfig.isDev ||
      AppConfig.apiBaseUrl.contains('desenvolvimento') ||
      AppConfig.apiBaseUrl.contains('localhost');

  @override
  void initState() {
    super.initState();
    _carregarTela();
  }

  Future<void> _carregarTela() async {
    final nome = await AuthStorage().obterNmcliente();
    if (mounted) {
      setState(() {
        _nomeCliente = (nome?.trim().isNotEmpty ?? false)
            ? nome!.trim()
            : 'Cliente';
        _mensagens.add(
          _MensagemCora(
            texto:
                'Olá, ${_primeiroNome(_nomeCliente)}! Eu sou a Cora. Como posso ajudar?',
            doCliente: false,
            horario: DateTime.now(),
          ),
        );
      });
    }
    await _consultarAmbiente();
  }

  String _primeiroNome(String nome) => nome.trim().split(RegExp(r'\s+')).first;

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
        _apiOnline =
            resposta.statusCode == 200 &&
            (dados['api'] == null || dados['api'] == 'online');
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

  void _enviarMensagem() {
    final texto = _mensagemController.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      _mensagens.add(
        _MensagemCora(texto: texto, doCliente: true, horario: DateTime.now()),
      );
      _mensagemController.clear();
    });
    _rolarParaFinal();
  }

  void _rolarParaFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _status(String texto, bool online) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 9, color: online ? Colors.green : Colors.red),
        const SizedBox(width: 5),
        Text(
          texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _cardAmbiente() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _status('API ${_apiOnline ? 'online' : 'offline'}', _apiOnline),
          _status('Banco ${_bancoOnline ? 'online' : 'offline'}', _bancoOnline),
          Text(
            _ambienteDev ? 'Desenvolvimento' : 'Produção',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const Text(
            'Versão 1.0.0',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _cardAtendimento({
    required IconData icone,
    required String titulo,
    required String descricao,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: cor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  descricao,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bolha(_MensagemCora mensagem) {
    return Align(
      alignment: mensagem.doCliente
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        decoration: BoxDecoration(
          color: mensagem.doCliente ? const Color(0xFFD9FDD3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(mensagem.doCliente ? 15 : 3),
            bottomRight: Radius.circular(mensagem.doCliente ? 3 : 15),
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensagem.doCliente ? _primeiroNome(_nomeCliente) : 'Cora',
              style: TextStyle(
                color: mensagem.doCliente
                    ? Colors.green.shade800
                    : Colors.blue.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(mensagem.texto),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${mensagem.horario.hour.toString().padLeft(2, '0')}:${mensagem.horario.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mensagemController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          const PerfilPageHeader(subtitulo: 'Fale conosco'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _cardAmbiente(),
                const SizedBox(height: 12),
                _cardAtendimento(
                  icone: Icons.schedule_rounded,
                  titulo: 'Horário de atendimento',
                  descricao: 'Segunda a sexta-feira, das 8h às 18h.',
                  cor: Colors.blue,
                ),
                const SizedBox(height: 9),
                _cardAtendimento(
                  icone: Icons.mark_email_read_outlined,
                  titulo: 'Prazo de resposta',
                  descricao:
                      'Nossa equipe responderá sua solicitação assim que possível.',
                  cor: Colors.green,
                ),
                const SizedBox(height: 9),
                _cardAtendimento(
                  icone: Icons.security_rounded,
                  titulo: 'Seus dados estão seguros',
                  descricao:
                      'As informações serão utilizadas somente para o atendimento.',
                  cor: Colors.orange,
                ),
                const SizedBox(height: 14),
                Container(
                  height: 330,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEAE2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: _mensagens.length,
                          itemBuilder: (_, index) => _bolha(_mensagens[index]),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _mensagemController,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _enviarMensagem(),
                                decoration: const InputDecoration(
                                  hintText: 'Digite sua mensagem...',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton.filled(
                              tooltip: 'Enviar',
                              onPressed: _enviarMensagem,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              icon: const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MensagemCora {
  final String texto;
  final bool doCliente;
  final DateTime horario;

  const _MensagemCora({
    required this.texto,
    required this.doCliente,
    required this.horario,
  });
}
