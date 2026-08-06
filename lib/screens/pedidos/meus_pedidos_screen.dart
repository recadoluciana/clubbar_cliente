import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../utils/value_formatters.dart';
import 'package:clubbar_cliente/config/app_config.dart';

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
  String nomeCliente = '';

  final TextEditingController _buscaController = TextEditingController();
  String termoBusca = '';
  String tipoSelecionado = 'P';
  String statusSelecionado = 'TODOS';

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

      final nome = await authStorage.obterNmcliente();
      final data = await apiService.buscarCompras(clienteId: id);

      setState(() {
        nomeCliente = nome ?? '';
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

  List<Map<String, dynamic>> get pedidosFiltrados {
    final pesquisa = termoBusca.trim().toLowerCase();

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

        final nomeProduto = (item['nmproduto'] ?? '').toString().toLowerCase();

        final descricao = (item['dsproduto'] ?? '').toString().toLowerCase();

        final observacao = (item['dsobsitvenda'] ?? '')
            .toString()
            .toLowerCase();

        final participante = (item['nmparticipante'] ?? '')
            .toString()
            .toLowerCase();

        final cpfParticipante = (item['cpfparticipante'] ?? '')
            .toString()
            .toLowerCase();

        final nomeLoja = (pedido['nmloja'] ?? '').toString().toLowerCase();

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

  Widget _filtrosTipo() {
    return Row(
      children: [
        Expanded(
          child: _botaoTipo(
            titulo: 'Produtos',
            icone: Icons.shopping_bag_outlined,
            tipo: 'P',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _botaoTipo(
            titulo: 'Ingressos',
            icone: Icons.confirmation_number_outlined,
            tipo: 'I',
          ),
        ),
      ],
    );
  }

  Widget _botaoTipo({
    required String titulo,
    required IconData icone,
    required String tipo,
  }) {
    final selecionado = tipoSelecionado == tipo;

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            tipoSelecionado = tipo;
          });
        },
        icon: Icon(icone, size: 20),
        label: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: selecionado ? Colors.amber : Colors.white,
          foregroundColor: Colors.black,
          elevation: selecionado ? 2 : 0,
          side: BorderSide(
            color: selecionado ? Colors.amber.shade700 : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
        ? Colors.blue.withOpacity(0.10)
        : Colors.amber.withOpacity(0.15);

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
            ? Colors.green.withOpacity(0.10)
            : Colors.red.withOpacity(0.10),
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

  Widget _logoLoja(String url) {
    if (url.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.storefront_outlined, color: Colors.amber.shade800),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: Colors.amber.shade800,
            ),
          );
        },
      ),
    );
  }

  Widget _itemPedido(Map<String, dynamic> item) {
    final obs = (item['dsobsitvenda'] ?? '').toString();
    final entreguePor =
        (item['nmuserentregaitvenda'] ?? item['userentregaitvenda'] ?? '')
            .toString();
    final dataEntrega = (item['dtentregaitvenda'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (item['nmproduto'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _badgeTipo(item),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chipInfo('Qtd: ${item['qtitvenda'] ?? 0}'),
                        _chipInfo(
                          'Valor: ${ValueFormatters.moeda(item['vrunititvenda'])}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _badgeEntrega(item),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  _chipInfo('Qtd: ${item['qtitvenda'] ?? 0}'),
                  const SizedBox(width: 8),
                  _chipInfo(
                    'Valor: ${ValueFormatters.moeda(item['vrunititvenda'])}',
                  ),
                  const Spacer(),
                  _badgeEntrega(item),
                ],
              );
            },
          ),
          if (obs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Observação: $obs',
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ],
          if (entreguePor.isNotEmpty || dataEntrega.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (entreguePor.isNotEmpty)
              Text(
                'Entregue por: $entreguePor',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            if (dataEntrega.isNotEmpty)
              Text(
                'Data da entrega: $dataEntrega',
                style: TextStyle(color: Colors.grey.shade700),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _logoLoja(
                    _buildImageUrl((pedido['urllogoloja'] ?? '').toString()),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (pedido['nmloja'] ?? 'Loja').toString(),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Compra: ${(pedido['dtcriacao'] ?? '').toString()}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    ValueFormatters.moeda(pedido['totalvenda']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...itens.map(_itemPedido),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Você ainda não tem nenuma compra.',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
        ],
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
                ClubbarPageHeader(
                  titulo: 'Minhas compras',
                  subtitulo: nomeCliente,
                  icone: Icons.receipt_long_rounded,
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: carregarPedidos,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _filtrosTipo(),

                        const SizedBox(height: 12),

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
