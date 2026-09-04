import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _quantidadeCtrl = TextEditingController(text: '1');
  final _observacaoCtrl = TextEditingController();

  bool carregando = true;
  bool adicionando = false;
  bool produtoAdicionado = false;
  String? erro;

  Map<String, dynamic>? produto;
  Loja? loja;

  @override
  void dispose() {
    _quantidadeCtrl.dispose();
    _observacaoCtrl.dispose();
    super.dispose();
  }

  int get _quantidade => int.tryParse(_quantidadeCtrl.text) ?? 1;

  void _alterarQuantidade(int valor) {
    final novaQuantidade = valor.clamp(1, 999);
    _quantidadeCtrl.value = TextEditingValue(
      text: '$novaQuantidade',
      selection: TextSelection.collapsed(offset: '$novaQuantidade'.length),
    );
    setState(() {});
  }

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

    final quantidade = int.tryParse(_quantidadeCtrl.text);
    if (quantidade == null || quantidade < 1 || quantidade > 999) {
      AppSnackBar.info(context, 'Informe uma quantidade entre 1 e 999.');
      return;
    }

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
        quantidade: quantidade,
        observacao: _observacaoCtrl.text.trim(),
      );

      final total = await apiService.buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );

      CartBadgeNotifier.atualizar(total);

      if (!mounted) return;

      AppSnackBar.info(
        context,
        quantidade == 1
            ? 'Produto adicionado ao carrinho.'
            : '$quantidade produtos adicionados ao carrinho.',
      );

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
        label: Text(
          'Adicionar $_quantidade ao carrinho',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

    final precoOriginal = _valorDouble(p?['vrprecoprod'] ?? 0);
    final precoFinal = _valorDouble(
      p?['vrprecofinal'] ?? p?['vrprecoprod'] ?? 0,
    );
    final descontoAtivo =
        p?['descontoativo'] == true ||
        p?['descontoativo'] == 1 ||
        p?['descontoativo']?.toString().toLowerCase() == 'true';
    final tipoDesconto = (p?['tipodesconto'] ?? '').toString().toUpperCase();
    final valorDesconto = _valorDouble(p?['vrdesconto']);
    final seloDesconto = tipoDesconto == 'PERCENTUAL'
        ? '${valorDesconto.toStringAsFixed(0)}% OFF'
        : '${ValueFormatters.moeda(valorDesconto)} OFF';

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
                  Stack(
                    children: [
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
                      if (descontoAtivo)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              seloDesconto,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                      Expanded(
                        child: Text(
                          descontoAtivo ? 'Preço promocional' : 'Preço',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (descontoAtivo)
                            Text(
                              ValueFormatters.moeda(precoOriginal),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            ValueFormatters.moeda(
                              descontoAtivo ? precoFinal : precoOriginal,
                            ),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: descontoAtivo
                                  ? Colors.green.shade700
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quantidade',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Diminuir quantidade',
                            onPressed: _quantidade > 1
                                ? () => _alterarQuantidade(_quantidade - 1)
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 84,
                            child: TextField(
                              controller: _quantidadeCtrl,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              onChanged: (_) => setState(() {}),
                              onEditingComplete: () {
                                _alterarQuantidade(
                                  int.tryParse(_quantidadeCtrl.text) ?? 1,
                                );
                                FocusScope.of(context).unfocus();
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            tooltip: 'Aumentar quantidade',
                            onPressed: _quantidade < 999
                                ? () => _alterarQuantidade(_quantidade + 1)
                                : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                          const Spacer(),
                          Text(
                            'Máximo 999',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _observacaoCtrl,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 255,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Observação (opcional)',
                          hintText: 'Ex.: sem gelo, pouco açúcar...',
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 40),
                            child: Icon(Icons.notes_rounded),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _botaoAdicionar(),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
