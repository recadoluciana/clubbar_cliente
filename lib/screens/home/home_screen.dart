import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/evento.dart';
import '../../models/loja.dart';
import '../../models/produto.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../detalhe_evento/detalhe_evento_screen.dart';
import '../detalhe_loja/detalhe_loja_screen.dart';
import '../login/login_screen.dart';
import '../produtos_loja/produto_compartilhado_screen.dart';
import '../../services/main_navigation_controller.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_config.dart';
import '../../utils/app_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final authStorage = AuthStorage();
  final apiService = ApiService();

  final PageController _pageController = PageController(viewportFraction: 0.86);
  final TextEditingController _buscaCtrl = TextEditingController();

  Timer? _timer;
  int _paginaAtual = 0;

  bool carregando = true;
  bool logado = false;
  String? erro;
  String? erroEventos;
  String? erroLojas;
  String? erroProdutos;
  String nomeCliente = '';
  String termoBusca = '';

  List<Evento> eventos = [];
  List<Evento> eventosCarrossel = [];
  List<Loja> lojas = [];
  List<Produto> produtosMaisVendidos = [];

  @override
  void initState() {
    super.initState();
    carregarHome();
  }

  Future<void> carregarHome() async {
    setState(() {
      carregando = true;
      erro = null;
      erroEventos = null;
      erroLojas = null;
      erroProdutos = null;
    });

    try {
      final token = await authStorage.obterToken();
      final nome = await authStorage.obterNmcliente();
      logado = token != null && token.isNotEmpty;
      nomeCliente = nome ?? '';

      final lojasFuture = apiService.buscarLojas();
      final eventosFuture = apiService.buscarEventos();
      final produtosFuture = apiService.buscarProdutosMaisVendidos();

      try {
        lojas = await lojasFuture;
      } catch (e) {
        lojas = [];
        erroLojas = apiService.mensagemErroAmigavel(e);
      }

      try {
        eventos = await eventosFuture;
        eventosCarrossel = eventos.take(10).toList(growable: false);
      } catch (e) {
        eventos = [];
        eventosCarrossel = [];
        erroEventos = apiService.mensagemErroAmigavel(e);
      }

      try {
        produtosMaisVendidos = await produtosFuture;
      } catch (e) {
        produtosMaisVendidos = [];
        erroProdutos = apiService.mensagemErroAmigavel(e);
      }

      _paginaAtual = 0;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
          iniciarCarousel();
        });
      }
    } catch (e) {
      erro = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  String _normalizar(String texto) {
    return texto.toLowerCase().trim();
  }

  List<Evento> get eventosFiltrados {
    if (termoBusca.trim().isEmpty) return eventos;

    final q = _normalizar(termoBusca);

    return eventos.where((evento) {
      final titulo = _normalizar(evento.titulo);
      final local = _normalizar(evento.local);
      final data = _normalizar(evento.data);

      return titulo.contains(q) || local.contains(q) || data.contains(q);
    }).toList();
  }

  List<Evento> get destaquesFiltrados {
    if (termoBusca.trim().isEmpty) return eventosCarrossel;
    return eventosFiltrados.take(10).toList(growable: false);
  }

  List<Loja> get lojasFiltradas {
    if (termoBusca.trim().isEmpty) return lojas;

    final q = _normalizar(termoBusca);

    return lojas.where((loja) {
      final nome = _normalizar(loja.nome);
      final endereco = _normalizar(loja.endereco);
      final bairro = _normalizar(loja.bairro);
      final cidade = _normalizar(loja.cidade);
      final instagram = _normalizar(loja.instagram);
      final dsestiloloja = _normalizar(loja.dsestiloloja);

      return nome.contains(q) ||
          endereco.contains(q) ||
          bairro.contains(q) ||
          cidade.contains(q) ||
          instagram.contains(q) ||
          dsestiloloja.contains(q);
    }).toList();
  }

  void iniciarCarousel() {
    _timer?.cancel();

    if (destaquesFiltrados.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (destaquesFiltrados.length <= 1) return;
      if (!_pageController.hasClients) return;

      _paginaAtual = (_paginaAtual + 1) % destaquesFiltrados.length;

      _pageController.animateToPage(
        _paginaAtual,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> sair() async {
    await authStorage.limparToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(mostrarVoltar: false),
      ),
      (_) => false,
    );
  }

  Future<void> compartilharLoja(Loja loja) async {
    final cidadeEstado = loja.sgEstado.isNotEmpty
        ? '${loja.cidade} - ${loja.sgEstado}'
        : loja.cidade;

    final texto =
        '''
🍻 ${loja.nome}

📍 ${loja.endereco}
${loja.bairro}
$cidadeEstado

🍺 Conheça esta casa pelo Clubbar

${AppConfig.appWebUrl}/?loja_id=${loja.id}
''';

    await Share.share(texto);
  }

  void abrirLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  String formatarDataEvento(String valor) {
    if (valor.trim().isEmpty) return 'Data não informada';

    try {
      final data = DateTime.parse(valor).toLocal();
      return DateFormat('dd/MM/yyyy - HH:mm').format(data);
    } catch (_) {
      return valor;
    }
  }

  Widget _imagemSegura({
    required String url,
    required double width,
    required double height,
    required IconData fallbackIcon,
    BoxFit fit = BoxFit.cover,
    double borderRadius = 0,
  }) {
    if (url.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        alignment: Alignment.center,
        child: Icon(fallbackIcon, size: 40),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, error) {
          debugPrint('ERRO AO CARREGAR IMAGEM: $error');
          debugPrint('URL DA IMAGEM: $url');
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade300,
            alignment: Alignment.center,
            child: Icon(fallbackIcon, size: 40),
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
      ),
    );
  }

  Widget _secaoTitulo(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icone, size: 20),
          const SizedBox(width: 7),
          Text(
            titulo,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _cardVazio(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  Loja? _lojaDoEvento(Evento evento) {
    for (final loja in lojas) {
      if (loja.id == evento.lojaId) return loja;
    }
    return null;
  }

  String _enderecoCompleto(Loja loja) {
    final rua = loja.endereco.trim().isEmpty ? '' : loja.endereco.trim();
    final ruaNumero = [
      if (rua.isNotEmpty) rua,
      if (loja.numero.trim().isNotEmpty) loja.numero.trim(),
    ].join(', ');
    final localidade = [
      if (loja.bairro.trim().isNotEmpty) loja.bairro.trim(),
      if (loja.cidade.trim().isNotEmpty) loja.cidade.trim(),
      if (loja.sgEstado.trim().isNotEmpty) loja.sgEstado.trim(),
    ].join(' - ');

    if (ruaNumero.isEmpty && localidade.isEmpty) {
      return 'Localização não informada';
    }
    if (ruaNumero.isEmpty) return localidade;
    if (localidade.isEmpty) return ruaNumero;
    return '$ruaNumero. $localidade';
  }

  String _telefoneFormatado(String telefone) {
    var numeros = telefone.replaceAll(RegExp(r'\D'), '');
    var prefixoPais = '';

    if ((numeros.length == 12 || numeros.length == 13) &&
        numeros.startsWith('55')) {
      numeros = numeros.substring(2);
      prefixoPais = '+55 ';
    }

    if (numeros.length == 11) {
      return '$prefixoPais(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-${numeros.substring(7)}';
    }
    if (numeros.length == 10) {
      return '$prefixoPais(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-${numeros.substring(6)}';
    }

    return telefone.trim();
  }

  bool _lojaNova(Loja loja) {
    final data = loja.dataCriacao;
    if (data == null) return false;
    final agora = DateTime.now();
    final anoMesAnterior = agora.month == 1 ? agora.year - 1 : agora.year;
    final mesAnterior = agora.month == 1 ? 12 : agora.month - 1;
    final diaLimite = min(
      agora.day,
      DateUtils.getDaysInMonth(anoMesAnterior, mesAnterior),
    );
    final limite = DateTime(
      anoMesAnterior,
      mesAnterior,
      diaLimite,
      agora.hour,
      agora.minute,
      agora.second,
    );
    return !data.isAfter(agora) && !data.isBefore(limite);
  }

  Widget _listaProdutosMaisVendidos() {
    if (erroProdutos != null) {
      return _cardErro(erroProdutos!, carregarHome);
    }
    if (produtosMaisVendidos.isEmpty) {
      return _cardVazio('Ainda não há produtos vendidos para destacar.');
    }

    return SizedBox(
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: produtosMaisVendidos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final produto = produtosMaisVendidos[index];
          return SizedBox(
            width: 132,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => MainNavigationController.abrirTela(
                  ProdutoCompartilhadoScreen(produtoId: produto.produtoId),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _imagemSegura(
                      url: produto.urlfotoproduto ?? '',
                      width: 132,
                      height: 85,
                      fallbackIcon: Icons.local_bar_outlined,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              produto.nmproduto,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.amber.shade800,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    produto.nmloja,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.amber.shade800,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _abrirEvento(Evento evento, Loja? lojaConhecida) async {
    try {
      final loja =
          lojaConhecida ?? await apiService.buscarDadosLoja(evento.lojaId);
      if (!mounted) return;
      MainNavigationController.abrirTela(
        DetalheEventoScreen(eventoId: evento.id, loja: loja),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(
        context,
        'Não foi possível carregar os dados do estabelecimento.',
      );
    }
  }

  Widget _cardErro(String texto, VoidCallback tentarNovamente) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 36),
            const SizedBox(height: 10),
            Text(texto, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: tentarNovamente,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
      child: TextField(
        controller: _buscaCtrl,
        onChanged: (value) {
          setState(() {
            termoBusca = value;
            _paginaAtual = 0;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          });

          iniciarCarousel();
        },
        decoration: InputDecoration(
          hintText: 'bar, casa noturna, estilo musical, cidade, bairro',
          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: termoBusca.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _buscaCtrl.clear();
                    setState(() {
                      termoBusca = '';
                      _paginaAtual = 0;
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(0);
                      }
                    });

                    iniciarCarousel();
                  },
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.amber, width: 1.6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        mostrarVoltar: false,
        actions: [
          if (!logado)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: abrirLogin,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.login_rounded, size: 21),
                label: const Text(
                  'Login',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: carregarHome,
        child: carregando
            ? const Center(child: CircularProgressIndicator())
            : erro != null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            erro!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: carregarHome,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                children: [
                  _campoBusca(),
                  const SizedBox(height: 15),

                  _secaoTitulo(
                    'Eventos em destaque',
                    Icons.celebration_outlined,
                  ),
                  const SizedBox(height: 10),

                  if (erroEventos != null)
                    _cardErro(erroEventos!, carregarHome)
                  else if (destaquesFiltrados.isEmpty)
                    _cardVazio('Nenhum evento encontrado.')
                  else
                    SizedBox(
                      height: 210,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: destaquesFiltrados.length,
                        onPageChanged: (index) {
                          setState(() {
                            _paginaAtual = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final evento = destaquesFiltrados[index];

                          final loja = _lojaDoEvento(evento);
                          final logoLoja = evento.logoLojaUrl.isNotEmpty
                              ? evento.logoLojaUrl
                              : (loja?.imagemUrl ?? '');

                          return GestureDetector(
                            onTap: () => _abrirEvento(evento, loja),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(21),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.14),
                                    blurRadius: 14,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(21),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _imagemSegura(
                                      url: evento.bannerUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fallbackIcon: Icons.image_not_supported,
                                    ),
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black54,
                                            Colors.black87,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      left: 14,
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(
                                          5,
                                          5,
                                          10,
                                          5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.68,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ClipOval(
                                              child: _imagemSegura(
                                                url: logoLoja,
                                                width: 34,
                                                height: 34,
                                                fallbackIcon:
                                                    Icons.storefront_outlined,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 180,
                                              ),
                                              child: Text(
                                                evento.nomeLoja.isEmpty
                                                    ? 'Estabelecimento'
                                                    : evento.nomeLoja,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 15,
                                      right: 15,
                                      bottom: 14,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            evento.titulo,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 19,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_month,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  formatarDataEvento(
                                                    evento.data,
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade200,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  evento.local.isEmpty
                                                      ? 'Local não informado'
                                                      : evento.local,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade300,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  if (destaquesFiltrados.length > 1) ...[
                    const SizedBox(height: 9),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(destaquesFiltrados.length, (
                        index,
                      ) {
                        final ativo = index == _paginaAtual;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: ativo ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: ativo ? Colors.amber : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }),
                    ),
                  ],

                  if (produtosMaisVendidos.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _secaoTitulo(
                      'Produtos mais vendidos',
                      Icons.local_fire_department_outlined,
                    ),
                    const SizedBox(height: 10),
                    _listaProdutosMaisVendidos(),
                    const SizedBox(height: 20),
                  ],

                  _secaoTitulo(
                    'Bares e Casas Noturnas',
                    Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 10),

                  if (erroLojas != null)
                    _cardErro(erroLojas!, carregarHome)
                  else if (lojasFiltradas.isEmpty)
                    _cardVazio('Nenhum bar ou casa noturna encontrado.')
                  else
                    ListView.builder(
                      itemCount: lojasFiltradas.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final loja = lojasFiltradas[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            elevation: 2,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                MainNavigationController.abrirTela(
                                  DetalheLojaScreen(loja: loja),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(11),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _imagemSegura(
                                      url: loja.imagemUrl,
                                      width: 84,
                                      height: 84,
                                      borderRadius: 42,
                                      fallbackIcon: Icons.storefront,
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  loja.nome,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (_lojaNova(loja)) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'NOVO',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  _enderecoCompleto(loja),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 11,
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (loja.nrtelloja
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.phone_outlined,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    _telefoneFormatado(
                                                      loja.nrtelloja,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade700,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 2),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  compartilharLoja(loja),
                                              icon: const Icon(
                                                Icons.ios_share_rounded,
                                                size: 15,
                                              ),
                                              label: const Text('Compartilhar'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    Colors.amber.shade900,
                                                backgroundColor:
                                                    Colors.amber.shade50,
                                                side: BorderSide(
                                                  color: Colors.amber.shade300,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 3,
                                                    ),
                                                minimumSize: const Size(0, 27),
                                                shape: const StadiumBorder(),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                textStyle: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}
