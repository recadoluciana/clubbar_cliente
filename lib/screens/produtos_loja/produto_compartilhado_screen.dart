import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/cart_badge_notifier.dart';
import '../../utils/value_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../screens/produtos_loja/produtos_loja_screen.dart';
import '../../services/main_navigation_controller.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/login_redirect.dart';
import 'package:clubbar_cliente/config/app_config.dart';

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
  bool produtoAdicionado = false;
  String? erro;

  Map<String, dynamic>? produto;
  Loja? loja;

  @override
  void initState() {
    super.initState();
    carregarProduto();
  }

  String _urlImagem(String? url) {
    if (url == null || url.trim().isEmpty) return '';

    if (url.startsWith('http')) {
      return url;
    }

    return '${AppConfig.apiBaseUrl}$url';
  }

  double _valorDouble(dynamic valor) {
    if (valor == null) return 0;

    if (valor is int) return valor.toDouble();
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();

    return double.tryParse(valor.toString()) ?? 0;
  }

  Future<void> carregarProduto() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final prod = await apiService.buscarProdutoCompartilhado(
        produtoId: widget.produtoId,
      );

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
      if (!mounted) return;

      if (clienteId == null || clienteId == 0) {
        await direcionarParaLogin(
          context,
          mensagem: 'Faça login para adicionar o produto ao carrinho.',
        );
        return;
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

      AppSnackBar.info(context, 'Produto adicionado ao carrinho.');

      MainNavigationController.abrirTela(
        ProdutosLojaScreen(
          loja: loja!,
          onVoltar: () {
            Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
    } finally {
      if (mounted) {
        setState(() => adicionando = false);
      }
    }
  }

  Widget _botaoAdicionar() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: adicionando ? null : adicionarAoCarrinho,
        icon: adicionando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Icon(Icons.add_shopping_cart_rounded),
        label: const Text(
          'Adicionar ao carrinho',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = produto;

    final imagemUrl = _urlImagem(p?['urlfotoproduto']?.toString());

    final preco = _valorDouble(p?['vrprecofinal'] ?? p?['vrprecoprod'] ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (imagemUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      height: 260,
                      width: double.infinity,
                      color: Colors.white,
                      child: Image.network(
                        imagemUrl,
                        height: 260,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 220,
                            width: double.infinity,
                            color: Colors.grey.shade300,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              size: 50,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  p?['nmproduto']?.toString() ?? '',
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
                    p?['dsproduto']?.toString() ?? '',
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
                        ValueFormatters.moeda(preco),
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
                _botaoAdicionar(),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
