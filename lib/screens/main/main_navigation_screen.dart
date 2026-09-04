import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../carteira/carteira_screen.dart';
import '../carrinho/carrinho_lojas_screen.dart';
import '../home/home_screen.dart';
import '../perfil/perfil_screen.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../services/main_navigation_controller.dart';
import '../pagamento/pagamento_sucesso_screen.dart';
import '../produtos_loja/produto_compartilhado_screen.dart';
import '../detalhe_evento/detalhe_evento_screen.dart';
import '../detalhe_loja/detalhe_loja_screen.dart';
import '../../utils/url_cleaner.dart';
import '../../utils/app_snackbar.dart';
import '../../services/deep_link_service.dart';
import '../../widgets/api_status_indicator.dart';
import '../atendimento_cora/atendimento_cora_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final authStorage = AuthStorage();
  final apiService = ApiService();

  int currentIndex = 0;
  int totalItensCarteira = 0;
  bool logado = false;
  String nomeCliente = '';

  @override
  void initState() {
    super.initState();
    carregarBadgeCarrinho();
    carregarBadgeCarteira();
    _carregarSessao();

    CarteiraBadgeNotifier.refresh.addListener(carregarBadgeCarteira);
    _verificarLinkProdutoCompartilhado();
    _verificarRetornoPagamentoWeb();
    _iniciarDeepLinksAndroid();
  }

  Widget _itemBarraNavegacao({
    required int index,
    required Widget icone,
    required String texto,
  }) {
    final selecionado = currentIndex == index;

    final corItem = selecionado ? Colors.black : Colors.black87;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _aoTocarNaAba(index),
          child: SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        color: corItem,
                        size: selecionado ? 23 : 22,
                      ),
                      child: SizedBox(height: 25, child: Center(child: icone)),
                    ),

                    // Espaço bem pequeno entre ícone e texto.
                    const SizedBox(height: 1),

                    Text(
                      texto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: corItem,
                        fontSize: 11,
                        height: 1,
                        fontWeight: selecionado
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraNavegacao() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              _itemBarraNavegacao(
                index: 0,
                icone: Icon(
                  currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                ),
                texto: 'Home',
              ),

              _itemBarraNavegacao(
                index: 1,
                icone: _iconeCarrinhoComBadge(selecionado: currentIndex == 1),
                texto: 'Carrinho',
              ),

              _itemBarraNavegacao(
                index: 2,
                icone: _iconeCarteiraComBadge(selecionado: currentIndex == 2),
                texto: 'Carteira',
              ),

              _itemBarraNavegacao(
                index: 3,
                icone: Icon(
                  currentIndex == 3 ? Icons.person : Icons.person_outline,
                ),
                texto: logado ? _primeiroNomeCliente : 'Perfil',
              ),

              Expanded(
                child: ApiStatusIndicator(
                  versao: '1.0.0',
                  onTap: () => MainNavigationController.abrirTela(
                    const AtendimentoCoraScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _aoTocarNaAba(int index) async {
    if (index == currentIndex) {
      MainNavigationController.limparTelasInternas();
      return;
    }

    final navegacaoAutorizada = await _selecionarAba(index);

    if (!mounted || !navegacaoAutorizada) return;

    MainNavigationController.limparTelasInternas();
    MainNavigationController.abaIndex.value = index;
  }

  Widget _buildPage() {
    switch (currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const CarrinhoLojasScreen();
      case 2:
        return const CarteiraScreen();
      case 3:
        return const PerfilScreen();
      default:
        return const HomeScreen();
    }
  }

  String get _primeiroNomeCliente {
    final partes = nomeCliente.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return 'Perfil';
    final nome = partes.first.toLowerCase();
    return '${nome[0].toUpperCase()}${nome.substring(1)}';
  }

  Future<void> _carregarSessao() async {
    final token = await authStorage.obterToken();
    final nome = await authStorage.obterNmcliente();
    if (!mounted) return;
    setState(() {
      logado = token != null && token.isNotEmpty;
      nomeCliente = nome ?? '';
    });
  }

  Future<bool> _estaLogado() async {
    final token = await authStorage.obterToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _iniciarDeepLinksAndroid() async {
    if (kIsWeb) return;

    final initialUri = await DeepLinkService.instance.getInitialLink();

    if (initialUri != null) {
      _abrirLinkCompartilhado(initialUri, limparUrl: false);
    }

    DeepLinkService.instance.start((uri) {
      _abrirLinkCompartilhado(uri, limparUrl: false);
    });
  }

  void _abrirLinkCompartilhado(Uri uri, {required bool limparUrl}) {
    final produtoIdTexto = uri.queryParameters['produto_id'];
    final eventoId = int.tryParse(uri.queryParameters['evento_id'] ?? '');
    final lojaId = int.tryParse(uri.queryParameters['loja_id'] ?? '');
    final produtoId = int.tryParse(produtoIdTexto ?? '');

    if (produtoId == null && eventoId == null && lojaId == null) return;

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (produtoId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProdutoCompartilhadoScreen(produtoId: produtoId),
            ),
          );
          return;
        }

        if (lojaId == null) return;
        final loja = await apiService.buscarDadosLoja(lojaId);
        if (!mounted) return;

        MainNavigationController.abrirTela(
          eventoId != null
              ? DetalheEventoScreen(eventoId: eventoId, loja: loja)
              : DetalheLojaScreen(loja: loja),
        );
      } catch (e) {
        if (mounted) {
          AppSnackBar.erro(
            context,
            'Não foi possível abrir o link compartilhado.',
          );
        }
      } finally {
        if (limparUrl) {
          limparUrlWeb();
        }
      }
    });
  }

  Future<void> _verificarRetornoPagamentoWeb() async {
    if (!kIsWeb) return;

    final checkoutId = Uri.base.queryParameters['checkout_id'];
    final retorno = Uri.base.queryParameters['pagamento'];
    if (checkoutId == null || checkoutId.isEmpty || retorno == null) return;
    limparUrlWeb();

    try {
      final api = ApiService();

      final response = await api.consultarCheckoutAsaas(checkoutId: checkoutId);

      final status = (response['status'] ?? '').toString().toUpperCase();

      final clienteId = await AuthStorage().obterClienteId();

      if (clienteId != null && clienteId > 0) {
        final totalCarrinho = await api.buscarQuantidadeCarrinho(
          clienteId: clienteId,
        );

        CartBadgeNotifier.atualizar(totalCarrinho);
        CarteiraBadgeNotifier.atualizar();
      }

      if (!mounted) return;

      if (status == 'PAGO') {
        MainNavigationController.abrirTela(
          const PagamentoSucessoScreen(sucesso: true),
        );
      } else {
        MainNavigationController.irParaCarrinho();
        AppSnackBar.erro(
          context,
          'Pagamento nao confirmado. O carrinho foi mantido.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          'Não foi possível confirmar o retorno do pagamento.',
        );
      }
    }
  }

  Future<void> carregarBadgeCarrinho() async {
    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        CartBadgeNotifier.limpar();
        return;
      }

      final total = await apiService.buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );

      CartBadgeNotifier.atualizar(total);
    } catch (_) {
      CartBadgeNotifier.limpar();
    }
  }

  Future<void> carregarBadgeCarteira() async {
    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        if (!mounted) return;
        setState(() {
          totalItensCarteira = 0;
        });
        return;
      }

      final total = await apiService.buscarQuantidadeCarteira(
        clienteId: clienteId,
      );

      if (!mounted) return;

      setState(() {
        totalItensCarteira = total;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        totalItensCarteira = 0;
      });
    }
  }

  Future<void> _verificarLinkProdutoCompartilhado() async {
    if (!kIsWeb) return;

    _abrirLinkCompartilhado(Uri.base, limparUrl: true);
  }

  @override
  void dispose() {
    CarteiraBadgeNotifier.refresh.removeListener(carregarBadgeCarteira);
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  Widget _iconeCarrinhoComBadge({required bool selecionado}) {
    return ValueListenableBuilder<int>(
      valueListenable: CartBadgeNotifier.totalItens,
      builder: (context, totalItensCarrinho, _) {
        final icone = Icon(
          selecionado ? Icons.shopping_cart : Icons.shopping_cart_outlined,
        );

        if (totalItensCarrinho <= 0) {
          return icone;
        }

        return Badge(
          backgroundColor: Colors.green,
          label: Text(
            totalItensCarrinho > 99 ? '99+' : '$totalItensCarrinho',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: icone,
        );
      },
    );
  }

  Widget _iconeCarteiraComBadge({required bool selecionado}) {
    return ValueListenableBuilder<int>(
      valueListenable: CarteiraBadgeNotifier.refresh,
      builder: (context, _, _) {
        final icone = Icon(
          selecionado
              ? Icons.account_balance_wallet
              : Icons.account_balance_wallet_outlined,
        );

        if (totalItensCarteira <= 0) {
          return icone;
        }

        return Badge(
          backgroundColor: Colors.green,
          label: Text(
            totalItensCarteira > 99 ? '99+' : '$totalItensCarteira',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: icone,
        );
      },
    );
  }

  Future<bool> _selecionarAba(int index) async {
    final exigeLogin = index == 1 || index == 2 || index == 3;

    if (exigeLogin) {
      final logado = await _estaLogado();

      if (!logado) {
        if (!mounted) return false;

        String mensagem = 'Faça login para continuar';

        if (index == 1) {
          mensagem = 'Faça login para acessar seu carrinho';
        } else if (index == 2) {
          mensagem = 'Faça login para acessar sua carteira';
        } else if (index == 3) {
          mensagem = 'Faça login para acessar o seu perfil.';
        }

        AppSnackBar.info(context, mensagem);
        return false;
      }
    }

    if (!mounted) return false;

    setState(() {
      currentIndex = index;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MainNavigationController.abaIndex,
      builder: (context, abaAtual, _) {
        currentIndex = abaAtual;

        return Scaffold(
          body: ValueListenableBuilder<Widget?>(
            valueListenable: MainNavigationController.telaInterna,
            builder: (context, telaInterna, _) {
              return PopScope(
                canPop: telaInterna == null && currentIndex == 0,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) {
                    if (telaInterna != null) {
                      MainNavigationController.fecharTelaInterna();
                    } else {
                      MainNavigationController.irParaHome();
                    }
                  }
                },
                child: telaInterna ?? _buildPage(),
              );
            },
          ),
          bottomNavigationBar: _barraNavegacao(),
        );
      },
    );
  }
}
