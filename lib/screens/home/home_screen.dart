import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/evento.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../detalhe_evento/detalhe_evento_screen.dart';
import '../detalhe_loja/detalhe_loja_screen.dart';
import '../login/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final authStorage = AuthStorage();
  final apiService = ApiService();

  final PageController _pageController = PageController(viewportFraction: 0.92);
  final TextEditingController _buscaCtrl = TextEditingController();

  Timer? _timer;
  int _paginaAtual = 0;

  bool carregando = true;
  bool logado = false;
  String? erro;
  String nomeCliente = '';
  String termoBusca = '';

  List<Evento> eventos = [];
  List<Loja> lojas = [];

  @override
  void initState() {
    super.initState();
    carregarHome();
  }

  Future<void> carregarHome() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final token = await authStorage.obterToken();
      final nome = await authStorage.obterNmcliente();
      final idCliente = await authStorage.obterClienteId();

      logado = token != null && token.isNotEmpty;
      nomeCliente = nome ?? '';

      try {
        lojas = await apiService.buscarLojas();

        for (final loja in lojas) {
          debugPrint('--------------------------------');
          debugPrint('id: ${loja.id}');
          debugPrint('nome: ${loja.nome}');
          debugPrint('bairro: ${loja.bairro}');
          debugPrint('horario: ${loja.horario}');
          debugPrint('instagram: ${loja.instagram}');
          debugPrint('imagemUrl: ${loja.imagemUrl}');
        }
      } catch (e) {
        lojas = [];
        debugPrint('Erro ao buscar bares: $e');
      }

      try {
        eventos = await apiService.buscarEventos();
      } catch (e) {
        eventos = [];
        debugPrint('Erro ao buscar eventos: $e');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        iniciarCarousel();
      });
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

  List<Loja> get lojasFiltradas {
    if (termoBusca.trim().isEmpty) return lojas;

    final q = _normalizar(termoBusca);

    return lojas.where((loja) {
      final nome = _normalizar(loja.nome);
      final bairro = _normalizar(loja.bairro);
      final horario = _normalizar(loja.horario);
      final instagram = _normalizar(loja.instagram);

      return nome.contains(q) ||
          bairro.contains(q) ||
          horario.contains(q) ||
          instagram.contains(q);
    }).toList();
  }

  void iniciarCarousel() {
    _timer?.cancel();

    if (eventosFiltrados.isEmpty) return;

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (eventosFiltrados.isEmpty) return;
      if (!_pageController.hasClients) return;

      _paginaAtual = (_paginaAtual + 1) % eventosFiltrados.length;

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

    setState(() {
      logado = false;
      nomeCliente = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logout realizado com sucesso')),
    );
  }

  Future<void> abrirLogin() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (resultado == true && mounted) {
      await carregarHome();
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(icone, size: 24),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _cardVazio(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  Widget _bannerLogin() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolha sua balada e prepare-se para se divertir!\n'
              'Compre seu ingresso e o que vai consumir.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),

            // Badge LOGIN
            InkWell(
              onTap: abrirLogin,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.login, color: Colors.black, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
          hintText: 'Bar, casa noturna, estilo musical, cidade ou bairro',
          prefixIcon: const Icon(Icons.search),
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
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
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
      appBar: const ClubbarAppBar(),
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
                  if (!logado) _bannerLogin(),
                  _campoBusca(),
                  const SizedBox(height: 22),

                  _secaoTitulo('Destaques', Icons.celebration_outlined),
                  const SizedBox(height: 14),

                  if (eventosFiltrados.isEmpty)
                    _cardVazio('Nenhum evento encontrado.')
                  else
                    SizedBox(
                      height: 280,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: eventosFiltrados.length,
                        onPageChanged: (index) {
                          setState(() {
                            _paginaAtual = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final evento = eventosFiltrados[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetalheEventoScreen(evento: evento),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.14),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
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
                                      left: 18,
                                      right: 18,
                                      bottom: 18,
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
                                              fontSize: 23,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_month,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  formatarDataEvento(
                                                    evento.data,
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade200,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  evento.local.isEmpty
                                                      ? 'Local não informado'
                                                      : evento.local,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade300,
                                                    fontSize: 14,
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

                  if (eventosFiltrados.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(eventosFiltrados.length, (index) {
                        final ativo = index == _paginaAtual;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: ativo ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ativo ? Colors.amber : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }),
                    ),
                  ],

                  const SizedBox(height: 28),

                  _secaoTitulo(
                    'Bares e Casas Noturnas',
                    Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 14),

                  if (lojasFiltradas.isEmpty)
                    _cardVazio('Nenhum bar ou casa noturna encontrado.')
                  else
                    ListView.builder(
                      itemCount: lojasFiltradas.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemBuilder: (context, index) {
                        final loja = lojasFiltradas[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            elevation: 2,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DetalheLojaScreen(loja: loja),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    _imagemSegura(
                                      url: loja.imagemUrl,
                                      width: 100,
                                      height: 100,
                                      borderRadius: 18,
                                      fallbackIcon: Icons.storefront,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            loja.nome,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  loja.bairro.isEmpty
                                                      ? 'Endereço não informado'
                                                      : loja.bairro,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  loja.horario.isEmpty
                                                      ? 'Horário não informado'
                                                      : loja.horario,
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 30,
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
