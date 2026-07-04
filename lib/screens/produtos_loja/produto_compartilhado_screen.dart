import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../utils/value_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';

class ProdutoCompartilhadoScreen extends StatefulWidget {
  final int produtoId;

  const ProdutoCompartilhadoScreen({super.key, required this.produtoId});

  @override
  State<ProdutoCompartilhadoScreen> createState() =>
      _ProdutoCompartilhadoScreenState();
}

class _ProdutoCompartilhadoScreenState
    extends State<ProdutoCompartilhadoScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = true;
  bool adicionando = false;
  String? erro;

  Map<String, dynamic>? produto;
  Loja? loja;

  @override
  void initState() {
    super.initState();
    carregarProduto();
  }

  Future<void> carregarProduto() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final lista = await apiService.buscarProdutoCompartilhado(
        produtoId: widget.produtoId,
      );

      if (lista.isEmpty) {
        throw Exception('Produto não encontrado.');
      }

      final prod = lista.first;
      final lojaDados = await apiService.buscarDadosLoja(prod['loja_id']);

      if (!mounted) return;

      setState(() {
        produto = prod;
        loja = lojaDados;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  Future<void> adicionarAoCarrinho() async {
    if (produto == null || loja == null) return;

    setState(() => adicionando = true);

    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Faça login para adicionar ao carrinho.');
      }

      await apiService.adicionarAoCarrinho(
        clienteId: clienteId,
        organizacaoId: loja!.organizacaoId,
        lojaId: loja!.id,
        produtoId: produto!['produto_id'],
        quantidade: 1,
        observacao: '',
      );

      final total = await apiService.buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );

      CartBadgeNotifier.atualizar(total);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto adicionado ao carrinho.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => adicionando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = produto;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? Center(child: Text(erro!))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if ((p?['urlfotoproduto'] ?? '').toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      p!['urlfotoproduto'],
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 20),

                Text(
                  p?['nmproduto'] ?? '',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                if (loja != null)
                  Text(
                    loja!.nome,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                const SizedBox(height: 16),

                if ((p?['dsproduto'] ?? '').toString().isNotEmpty)
                  Text(
                    p!['dsproduto'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Preço',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        ValueFormatters.moeda(
                          (p?['vrprecofinal'] ?? p?['vrprecoprod'] ?? 0)
                              .toDouble(),
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: adicionando ? null : adicionarAoCarrinho,
                    icon: adicionando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text(
                      'Adicionar ao carrinho',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
