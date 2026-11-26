import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../services/auth_storage.dart';
import '../../services/main_navigation_controller.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../detalhe_loja/detalhe_loja_screen.dart';
import '../main/main_navigation_screen.dart';

class PagamentoSucessoScreen extends StatefulWidget {
  final bool sucesso;
  final double cashbackGerado;
  final String? tituloSucesso;
  final String? descricaoSucesso;
  final String tituloAppBar;
  final Loja? lojaDestino;

  const PagamentoSucessoScreen({
    super.key,
    this.sucesso = true,
    this.cashbackGerado = 0,
    this.tituloSucesso,
    this.descricaoSucesso,
    this.tituloAppBar = 'Pagamento',
    this.lojaDestino,
  });

  @override
  State<PagamentoSucessoScreen> createState() => _PagamentoSucessoScreenState();
}

class _PagamentoSucessoScreenState extends State<PagamentoSucessoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacaoCelebracao;

  @override
  void initState() {
    super.initState();
    _animacaoCelebracao = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.sucesso) _animacaoCelebracao.forward();
    _atualizarBadges();
  }

  @override
  void dispose() {
    _animacaoCelebracao.dispose();
    super.dispose();
  }

  Future<void> _atualizarBadges() async {
    try {
      final clienteId = await AuthStorage().obterClienteId();

      if (clienteId == null || clienteId == 0) return;

      final qtdCarrinho = await ApiService().buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );

      CartBadgeNotifier.atualizar(qtdCarrinho);

      // força atualização da carteira
      CarteiraBadgeNotifier.atualizar();
    } catch (e) {
      debugPrint('Erro ao atualizar badges: $e');
    }
  }

  void _voltarAoApp() {
    final loja = widget.lojaDestino;
    if (loja != null) {
      MainNavigationController.limparTelasInternas();
      MainNavigationController.abrirTela(DetalheLojaScreen(loja: loja));
    } else {
      MainNavigationController.irParaHome();
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sucesso = widget.sucesso;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(
        titulo: widget.tituloAppBar,
        mostrarVoltar: false,
        mostrarSessao: false,
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sucesso) ...[
                    ScaleTransition(
                      scale: Tween<double>(begin: .85, end: 1).animate(
                        CurvedAnimation(
                          parent: _animacaoCelebracao,
                          curve: const Interval(
                            0,
                            .2,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                      ),
                      child: const Text('🎉', style: TextStyle(fontSize: 58)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    width: 420,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: (sucesso ? Colors.green : Colors.red)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            sucesso ? Icons.check_circle : Icons.error_outline,
                            color: sucesso ? Colors.green : Colors.red,
                            size: 64,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          sucesso
                              ? (widget.tituloSucesso ??
                                    'Pagamento realizado com sucesso')
                              : 'Pagamento cancelado pelo cliente',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        if (sucesso && widget.cashbackGerado > 0) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.amber.shade600),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.savings_rounded,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Você ganhou ${_moeda(widget.cashbackGerado)} de cashback para usar nas próximas compras de produtos desta loja. O saldo será liberado conforme as regras do estabelecimento.',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        Text(
                          sucesso
                              ? (widget.descricaoSucesso ??
                                    'Acompanhe sua compra através de sua carteira.')
                              : 'Não foi possível concluir o pagamento. Você pode tentar novamente pelo carrinho.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 26),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _voltarAoApp,
                            icon: Icon(
                              widget.lojaDestino == null
                                  ? Icons.home
                                  : Icons.storefront_outlined,
                            ),
                            label: Text(
                              widget.lojaDestino == null
                                  ? 'Ir para Home'
                                  : 'Voltar para ${widget.lojaDestino!.nome}',
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (sucesso && !MediaQuery.of(context).disableAnimations)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConfetesPainter(_animacaoCelebracao),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _moeda(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _ConfetesPainter extends CustomPainter {
  _ConfetesPainter(this.animacao) : super(repaint: animacao);

  final Animation<double> animacao;
  static const _cores = [
    Color(0xFFFFC107),
    Color(0xFFEF5350),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final tempo = animacao.value;
    if (tempo >= 1 || size.isEmpty) return;
    final origem = Offset(size.width / 2, 75);
    final opacidade = tempo < .75 ? 1.0 : (1 - tempo) / .25;
    for (var i = 0; i < 42; i++) {
      final angulo = (i / 42) * math.pi * 2;
      final distancia =
          (40 + (i % 5) * 17) *
          Curves.easeOut.transform((tempo * 4).clamp(0.0, 1.0));
      final queda = size.height * .72 * tempo * tempo * (0.6 + (i % 4) * .15);
      final x =
          origem.dx +
          math.cos(angulo) * distancia +
          math.sin(tempo * 10 + i) * 8;
      final y = origem.dy + math.sin(angulo) * distancia + queda;
      final paint = Paint()
        ..color = _cores[i % _cores.length].withValues(alpha: opacidade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angulo + tempo * math.pi * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 5, height: 9),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfetesPainter oldDelegate) =>
      oldDelegate.animacao != animacao;
}
