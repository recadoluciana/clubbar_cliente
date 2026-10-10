import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/perfil_page_header.dart';
import '../../utils/value_formatters.dart';
import 'package:clubbar_cliente/config/app_config.dart';
import '../perfil/cancelar_transacao_screen.dart';

class MeusPedidosScreen extends StatefulWidget {
  const MeusPedidosScreen({super.key});

  @override
  State<MeusPedidosScreen> createState() => _MeusPedidosScreenState();
}

class _MeusPedidosScreenState extends State<MeusPedidosScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  static final String baseUrl = AppConfig.apiBaseUrl;

  bool carregando = true;
  String? erro;
  int? clienteId;

  final TextEditingController _buscaController = TextEditingController();
  String termoBusca = '';
  String tipoSelecionado = 'P';
  String statusSelecionado = 'TODOS';
  final Set<int> _vendasExpandidas = <int>{};

  List<Map<String, dynamic>> pedidos = [];

  String _buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  @override
  void initState() {
    super.initState();
    carregarPedidos();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> carregarPedidos() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final id = await authStorage.obterClienteId();

      if (id == null || id == 0) {
        throw Exception('Cliente não identificado. Faça login novamente.');
      }

      clienteId = id;

      final data = await apiService.buscarCompras(clienteId: id);

      setState(() {
        pedidos = data;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = apiService.mensagemErroAmigavel(e);
        pedidos = [];
        carregando = false;
      });
    }
  }

  Future<void> _abrirCancelamento(Map<String, dynamic> pedido) async {
    final vendaId = int.tryParse('${pedido['venda_id'] ?? ''}');
    if (vendaId == null || vendaId <= 0) {
      return;
    }

    final cancelada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CancelarTransacaoScreen(vendaId: vendaId),
      ),
    );
    if (cancelada == true && mounted) {
      await carregarPedidos();
    }
  }

  List<Map<String, dynamic>> get pedidosFiltrados {
    final pesquisa = _normalizar(termoBusca);

    final resultado = <Map<String, dynamic>>[];

    for (final pedido in pedidos) {
      final itensOriginais = (pedido['itens'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final itensFiltrados = itensOriginais.where((item) {
        final tipo = (item['idtipoproduto'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

        if (tipo != tipoSelecionado) {
          return false;
        }

        final usado = (item['identregaitvenda'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

        if (statusSelecionado != 'TODOS' && usado != statusSelecionado) {
          return false;
        }

        if (pesquisa.isEmpty) {
          return true;
        }

        final nomeProduto = _normalizar((item['nmproduto'] ?? '').toString());

        final descricao = _normalizar((item['dsproduto'] ?? '').toString());

        final observacao = _normalizar((item['dsobsitvenda'] ?? '').toString());

        final participante = _normalizar(
          (item['nmparticipante'] ?? '').toString(),
        );

        final cpfParticipante = _normalizar(
          (item['cpfparticipante'] ?? '').toString(),
        );

        final nomeLoja = _normalizar((pedido['nmloja'] ?? '').toString());

        return nomeProduto.contains(pesquisa) ||
            descricao.contains(pesquisa) ||
            observacao.contains(pesquisa) ||
            participante.contains(pesquisa) ||
            cpfParticipante.contains(pesquisa) ||
            nomeLoja.contains(pesquisa);
      }).toList();

      if (itensFiltrados.isNotEmpty) {
        resultado.add({...pedido, 'itens': itensFiltrados});
      }
    }

    return resultado;
  }

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  Widget _filtrosTipo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: _abaTipo(
              titulo: 'Produtos',
              icone: Icons.shopping_bag_outlined,
              tipo: 'P',
            ),
          ),
          Expanded(
            child: _abaTipo(
              titulo: 'Ingressos',
              icone: Icons.confirmation_number_outlined,
              tipo: 'I',
            ),
          ),
        ],
      ),
    );
  }

  Widget _abaTipo({
    required String titulo,
    required IconData icone,
    required String tipo,
  }) {
    final selecionado = tipoSelecionado == tipo;

    return InkWell(
      onTap: () => setState(() => tipoSelecionado = tipo),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: selecionado ? Colors.amber.withValues(alpha: 0.16) : null,
          border: Border(
            bottom: BorderSide(
              color: selecionado ? Colors.amber.shade800 : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icone,
              size: 19,
              color: selecionado ? Colors.amber.shade900 : Colors.black54,
            ),
            const SizedBox(width: 7),
            Text(
              titulo,
              style: TextStyle(
                color: selecionado ? Colors.black : Colors.black54,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoPesquisa() {
    return TextField(
      controller: _buscaController,
      onChanged: (valor) {
        setState(() {
          termoBusca = valor;
        });
      },
      decoration: InputDecoration(
        hintText: tipoSelecionado == 'I'
            ? 'Pesquisar ingresso, participante, CPF ou bar'
            : 'Pesquisar produto, descrição, observação ou bar',
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: termoBusca.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _buscaController.clear();

                  setState(() {
                    termoBusca = '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.amber, width: 1.6),
        ),
      ),
    );
  }

  bool _isIngresso(Map<String, dynamic> item) {
    return (item['idtipoproduto'] ?? '').toString().toUpperCase() == 'I';
  }

  Widget _badgeTipo(Map<String, dynamic> item) {
    final ingresso = _isIngresso(item);
    final cor = ingresso ? Colors.blue : Colors.amber.shade800;
    final fundo = ingresso
        ? Colors.blue.withValues(alpha: 0.10)
        : Colors.amber.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        ingresso ? 'Ingresso' : 'Produto',
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _badgeEntrega(Map<String, dynamic> item) {
    final entregue =
        (item['identregaitvenda'] ?? '').toString().toUpperCase() == 'SIM';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: entregue
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        entregue ? 'Utilizado' : 'Não utilizado',
        style: TextStyle(
          color: entregue ? Colors.green : Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget? _badgeSituacaoItem(Map<String, dynamic> item) {
    final situacao = (item['sititvenda'] ?? 'ATIVO').toString().toUpperCase();
    final dados = switch (situacao) {
      'CANCELAMENTO_SOLICITADO' => (
        'Cancelamento solicitado',
        Colors.orange.shade800,
        Colors.orange.withValues(alpha: 0.12),
      ),
      'CANCELADO' => (
        'Cancelado',
        Colors.red,
        Colors.red.withValues(alpha: 0.10),
      ),
      _ => null,
    };
    if (dados == null) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dados.$3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dados.$1,
        style: TextStyle(
          color: dados.$2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _chipInfo(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _fotoProduto(Map<String, dynamic> item, {double tamanho = 52}) {
    final url = _buildImageUrl((item['urlfotoproduto'] ?? '').toString());
    final ingresso = _isIngresso(item);
    if (url.isEmpty) {
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: (ingresso ? Colors.blue : Colors.amber).withValues(
            alpha: 0.15,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          ingresso
              ? Icons.confirmation_number_outlined
              : Icons.shopping_bag_outlined,
          color: ingresso ? Colors.blue : Colors.amber.shade800,
          size: tamanho * 0.48,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Container(
            width: tamanho,
            height: tamanho,
            decoration: BoxDecoration(
              color: (ingresso ? Colors.blue : Colors.amber).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ingresso
                  ? Icons.confirmation_number_outlined
                  : Icons.shopping_bag_outlined,
              color: ingresso ? Colors.blue : Colors.amber.shade800,
            ),
          );
        },
      ),
    );
  }

  Widget _fotoEstabelecimento(String url, {double tamanho = 50}) {
    if (url.isEmpty) {
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.storefront_outlined,
          color: Colors.amber.shade800,
          size: tamanho * 0.48,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: tamanho,
          height: tamanho,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.storefront_outlined,
            color: Colors.amber.shade800,
            size: tamanho * 0.48,
          ),
        ),
      ),
    );
  }

  Widget _itemPedido(Map<String, dynamic> item) {
    final obs = (item['dsobsitvenda'] ?? '').toString();
    final entreguePor =
        (item['nmuserentregaitvenda'] ?? item['userentregaitvenda'] ?? '')
            .toString();
    final dataEntrega = (item['dtentregaitvenda'] ?? '').toString();
    final ingresso = _isIngresso(item);
    final dataEvento = (item['dtinicioevento'] ?? '').toString().trim();
    final tipoIngresso = (item['tipo_ingresso'] ?? '').toString().trim();
    final lote = (item['lote'] ?? '').toString().trim();
    final participante = (item['nmparticipante'] ?? '').toString().trim();
    final cpfParticipante = (item['cpfparticipante'] ?? '').toString().trim();
    final dataCancelamento = (item['dtcancelamento'] ?? '').toString().trim();
    final idReembolso = (item['idreembolso'] ?? '').toString().trim();
    final reembolso = item['vrreembolso'];
    final taxa = item['vrtaxaitvenda'] ?? 0;
    final badgeSituacao = _badgeSituacaoItem(item);
    final historico = (item['historico_participantes'] as List? ?? [])
        .map((valor) => Map<String, dynamic>.from(valor as Map))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fotoProduto(item, tamanho: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['nmproduto'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (ingresso && dataEvento.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Evento: $dataEvento',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _badgeTipo(item),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (ingresso && tipoIngresso.isNotEmpty)
                _chipInfo('Tipo: $tipoIngresso'),
              if (ingresso && lote.isNotEmpty) _chipInfo('Lote: $lote'),
              if (!ingresso) _chipInfo('Qtd: ${item['qtitvenda'] ?? 0}'),
              _chipInfo(
                'Valor: ${ValueFormatters.moeda(item['vrunititvenda'])}',
              ),
              if (ingresso) _chipInfo('Taxa: ${ValueFormatters.moeda(taxa)}'),
              _badgeEntrega(item),
              if (badgeSituacao case final Widget situacao) situacao,
            ],
          ),
          if (obs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Observação: $obs',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ],
          if (ingresso && participante.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Participante: $participante${cpfParticipante.isEmpty ? '' : ' • CPF: $cpfParticipante'}',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (ingresso && historico.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'Participantes anteriores',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            ...historico.map((registro) {
              final nome = (registro['nmparticipanteanterior'] ?? '')
                  .toString()
                  .trim();
              final cpf = (registro['cpfparticipanteanterior'] ?? '')
                  .toString()
                  .trim();
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• ${nome.isEmpty ? 'Não informado' : nome}${cpf.isEmpty ? '' : ' • CPF: $cpf'}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                ),
              );
            }),
          ],
          if (dataCancelamento.isNotEmpty ||
              reembolso != null ||
              idReembolso.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 3,
                children: [
                  if (dataCancelamento.isNotEmpty)
                    Text('Cancelamento: $dataCancelamento'),
                  if (reembolso != null)
                    Text('Reembolso: ${ValueFormatters.moeda(reembolso)}'),
                  if (idReembolso.isNotEmpty) Text('Código: $idReembolso'),
                ],
              ),
            ),
          ],
          if (entreguePor.isNotEmpty || dataEntrega.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              '${entreguePor.isEmpty ? '' : 'Entregue por: $entreguePor'}${entreguePor.isNotEmpty && dataEntrega.isNotEmpty ? ' • ' : ''}${dataEntrega.isEmpty ? '' : 'Data: $dataEntrega'}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardPedido(Map<String, dynamic> pedido) {
    final itens = (pedido['itens'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final vendaId = int.tryParse('${pedido['venda_id'] ?? ''}') ?? 0;
    final expandida = _vendasExpandidas.contains(vendaId);
    final podeCancelar =
        (pedido['sitvenda'] ?? '').toString().toUpperCase() == 'PAGA';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() {
                if (expandida) {
                  _vendasExpandidas.remove(vendaId);
                } else {
                  _vendasExpandidas.add(vendaId);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _fotoEstabelecimento(
                      _buildImageUrl((pedido['urllogoloja'] ?? '').toString()),
                      tamanho: 50,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (pedido['nmloja'] ?? 'Loja').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Venda #$vendaId • ${(pedido['dtcriacao'] ?? '').toString()}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${itens.length} ${itens.length == 1 ? 'item' : 'itens'}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          ValueFormatters.moeda(pedido['totalvenda']),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              expandida ? 'Ocultar' : 'Ver itens',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(
                              expandida
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (expandida) ...[
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    ...itens.map(_itemPedido),
                    if (podeCancelar)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _abrirCancelamento(pedido),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar compra'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _erroWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 14),
            Text(
              erro ?? 'Erro ao carregar compras',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: carregarPedidos,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                PerfilPageHeader(
                  subtitulo: 'Minhas compras',
                  conteudoInferior: _filtrosTipo(),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: carregarPedidos,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _filtrosStatus(),

                        const SizedBox(height: 14),

                        _campoPesquisa(),

                        const SizedBox(height: 20),

                        if (erro != null)
                          _erroWidget()
                        else if (pedidosFiltrados.isEmpty)
                          _estadoVazioPesquisa()
                        else
                          ...pedidosFiltrados.map(_cardPedido),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _estadoVazioPesquisa() {
    final ingresso = tipoSelecionado == 'I';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            ingresso
                ? Icons.confirmation_number_outlined
                : Icons.shopping_bag_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          Text(
            termoBusca.trim().isNotEmpty
                ? 'Nenhum resultado encontrado'
                : ingresso
                ? 'Nenhum ingresso encontrado'
                : 'Nenhum produto encontrado',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (termoBusca.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tente pesquisar usando outro nome ou termo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filtrosStatus() {
    return Row(
      children: [
        Expanded(
          child: _botaoStatus(
            titulo: 'Todos',
            status: 'TODOS',
            icone: Icons.all_inbox_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _botaoStatus(
            titulo: 'Não utilizados',
            status: 'NAO',
            icone: Icons.hourglass_bottom_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _botaoStatus(
            titulo: 'Utilizados',
            status: 'SIM',
            icone: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _botaoStatus({
    required String titulo,
    required String status,
    required IconData icone,
  }) {
    final selecionado = statusSelecionado == status;

    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            statusSelecionado = status;
          });
        },
        icon: Icon(icone, size: 17),
        label: Text(
          titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: selecionado ? Colors.amber : Colors.white,
          foregroundColor: Colors.black,
          side: BorderSide(
            color: selecionado ? Colors.amber.shade700 : Colors.grey.shade300,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
