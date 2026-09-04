import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import 'politica_compra_screen.dart';
import 'asaas_checkout_screen.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import 'pagamento_sucesso_screen.dart';
import 'pix_pagamento_screen.dart';

class EscolhaPagamentoScreen extends StatefulWidget {
  final Loja loja;

  final double totalProdutos;
  final double totalIngressos;

  final double? taxaConveniencia;
  final double? totalPagar;

  final VoidCallback? onVoltar;
  final int? reservaIngressoId;

  const EscolhaPagamentoScreen({
    super.key,
    required this.loja,
    required this.totalProdutos,
    this.totalIngressos = 0,
    this.taxaConveniencia,
    this.totalPagar,
    this.onVoltar,
    this.reservaIngressoId,
  });

  @override
  State<EscolhaPagamentoScreen> createState() => _EscolhaPagamentoScreenState();
}

class _EscolhaPagamentoScreenState extends State<EscolhaPagamentoScreen> {
  final ApiService apiService = ApiService();
  final AuthStorage authStorage = AuthStorage();

  String? _metodoPagamentoProcessando;
  bool carregandoCashback = false;
  bool usarCashback = false;
  double cashbackUtilizavel = 0;
  double saldoCashback = 0;

  bool get carregandoPagamento => _metodoPagamentoProcessando != null;

  @override
  void initState() {
    super.initState();
    if (widget.reservaIngressoId == null && widget.totalProdutos > 0) {
      _carregarCashback();
    }
  }

  Future<void> _carregarCashback() async {
    setState(() => carregandoCashback = true);
    try {
      final clienteId = await authStorage.obterClienteId();
      if (clienteId == null) return;
      final dados = await apiService.cashbackDisponivel(
        clienteId: clienteId,
        lojaId: widget.loja.id,
        totalCompra: widget.totalProdutos,
      );
      if (mounted) {
        setState(() {
          cashbackUtilizavel =
              double.tryParse('${dados['valor_utilizavel']}') ?? 0;
          saldoCashback = double.tryParse('${dados['saldo_disponivel']}') ?? 0;
        });
      }
    } finally {
      if (mounted) setState(() => carregandoCashback = false);
    }
  }

  double get percentualTaxaProduto => widget.loja.vrtaxaprod;
  double get percentualTaxaIngresso => widget.loja.vrtaxaing;

  double get taxaProdutoSplit =>
      widget.totalProdutos * (percentualTaxaProduto / 100);

  double get taxaIngressoCliente =>
      widget.totalIngressos * (percentualTaxaIngresso / 100);

  double get taxaClubbarTotal => taxaProdutoSplit + taxaIngressoCliente;

  bool get compraDeProdutos => widget.reservaIngressoId == null;

  double get cashbackAplicado =>
      compraDeProdutos && usarCashback ? cashbackUtilizavel : 0;

  double get totalPagar =>
      widget.totalProdutos +
      widget.totalIngressos +
      taxaIngressoCliente -
      cashbackAplicado;

  double get valorParceiro => totalPagar - taxaClubbarTotal;

  String _moeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> abrirPix() async {
    if (totalPagar < 5.00) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O pagamento mínimo é R\$ 5,00.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _metodoPagamentoProcessando = 'PIX');
    try {
      final clienteId = await authStorage.obterClienteId();
      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }
      final pagamento = widget.reservaIngressoId != null
          ? await apiService.criarPixReserva(
              reservaId: widget.reservaIngressoId!,
              clienteId: clienteId,
            )
          : await apiService.criarPixAsaas(
              clienteId: clienteId,
              organizacaoId: widget.loja.organizacaoId,
              lojaId: widget.loja.id,
              percentualTaxaIngresso: percentualTaxaIngresso,
              percentualTaxaProduto: percentualTaxaProduto,
              usarCashback: usarCashback,
              valorCashback: usarCashback ? cashbackUtilizavel : null,
            );
      if (!mounted) return;
      final resultadoPix = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PixPagamentoScreen(
            loja: widget.loja,
            pagamento: pagamento,
            reservaIngressoId: widget.reservaIngressoId,
            clienteId: clienteId,
          ),
        ),
      );
      if (resultadoPix == false && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _metodoPagamentoProcessando = null);
    }
  }

  Future<void> abrirAsaas() async {
    if (totalPagar < 5.00) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O pagamento mínimo é R\$5,00. Adicione mais itens ao carrinho para prosseguir com o pagamento.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _metodoPagamentoProcessando = 'CARTAO');

    try {
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }

      final resposta = widget.reservaIngressoId != null
          ? await apiService.criarCheckoutReserva(
              reservaId: widget.reservaIngressoId!,
              clienteId: clienteId,
            )
          : await apiService.pagarAsaas(
              clienteId: clienteId,
              organizacaoId: widget.loja.organizacaoId,
              lojaId: widget.loja.id,
              percentualTaxaIngresso: percentualTaxaIngresso,
              percentualTaxaProduto: percentualTaxaProduto,
              usarCashback: usarCashback,
              valorCashback: usarCashback ? cashbackUtilizavel : null,
            );

      final checkoutUrl = resposta['checkout_url'];

      if (checkoutUrl == null || checkoutUrl.toString().isEmpty) {
        throw Exception('Checkout Asaas não retornado.');
      }

      if (!mounted) return;
      if (kIsWeb) {
        await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_self');
      } else {
        final resultado = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AsaasCheckoutScreen(url: checkoutUrl.toString()),
          ),
        );

        if (resultado != true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pagamento nao concluido. O carrinho foi mantido.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
          return;
        }
        if (resultado == true) {
          if (!mounted) return;

          Map<String, dynamic>? confirmacao;
          for (var tentativa = 0; tentativa < 6; tentativa++) {
            confirmacao = widget.reservaIngressoId != null
                ? await apiService.consultarReserva(
                    reservaId: widget.reservaIngressoId!,
                    clienteId: clienteId,
                  )
                : await apiService.consultarCheckoutAsaas(
                    checkoutId: resposta['pagamento_id'].toString(),
                  );
            if ((confirmacao['status'] ?? '').toString().toUpperCase() ==
                    'PAGO' ||
                (confirmacao['status_pagamento'] ?? '')
                        .toString()
                        .toUpperCase() ==
                    'PAGO') {
              break;
            }
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          final confirmado =
              (confirmacao?['status'] ?? '').toString().toUpperCase() ==
                  'PAGO' ||
              (confirmacao?['status_pagamento'] ?? '')
                      .toString()
                      .toUpperCase() ==
                  'PAGO';

          if (!confirmado) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Pagamento nao confirmado. O carrinho foi mantido.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pop(context);
            return;
          }

          final clienteAtualId = await authStorage.obterClienteId();

          if (clienteAtualId != null && clienteAtualId > 0) {
            final totalCarrinho = await apiService.buscarQuantidadeCarrinho(
              clienteId: clienteAtualId,
            );

            CartBadgeNotifier.atualizar(totalCarrinho);
            CarteiraBadgeNotifier.atualizar();
          }

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PagamentoSucessoScreen(
                sucesso: true,
                cashbackGerado:
                    double.tryParse(
                      '${confirmacao?['cashback_gerado'] ?? 0}',
                    ) ??
                    0,
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _metodoPagamentoProcessando = null);
      }
    }
  }

  Widget _linhaResumo(String titulo, double valor, {bool destaque = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: destaque ? 18 : 15,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        Text(
          _moeda(valor),
          style: TextStyle(
            fontSize: destaque ? 18 : 15,
            fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _linhaCashback() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Cashback',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '- ${_moeda(cashbackAplicado)}',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _linhaResumoComIcone({
    required IconData icon,
    required String titulo,
    required double valor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.black87),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          _moeda(valor),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(mostrarVoltar: true, onVoltar: widget.onVoltar),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Text(
              widget.loja.nome,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Resumo da compra',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                if (compraDeProdutos) ...[
                  _linhaResumoComIcone(
                    icon: Icons.shopping_bag_outlined,
                    titulo: 'Produtos',
                    valor: widget.totalProdutos,
                  ),
                  const SizedBox(height: 16),
                  _linhaCashback(),
                  if (carregandoCashback || saldoCashback > 0) ...[
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: usarCashback,
                      onChanged: cashbackUtilizavel > 0 && !carregandoPagamento
                          ? (value) => setState(() => usarCashback = value)
                          : null,
                      secondary: const Icon(
                        Icons.savings_outlined,
                        color: Colors.amber,
                      ),
                      title: const Text(
                        'Usar saldo cashback',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        carregandoCashback
                            ? 'Consultando saldo...'
                            : 'Saldo: ${_moeda(saldoCashback)} • Uso nesta compra: ${_moeda(cashbackUtilizavel)}',
                      ),
                    ),
                  ],
                ] else ...[
                  _linhaResumoComIcone(
                    icon: Icons.confirmation_number_outlined,
                    titulo: 'Ingressos',
                    valor: widget.totalIngressos,
                  ),
                  const SizedBox(height: 10),
                  _linhaResumo(
                    'Taxa de conveniência (${percentualTaxaIngresso.toStringAsFixed(0)}%)',
                    taxaIngressoCliente,
                  ),
                ],
                const Divider(height: 28),
                _linhaResumo('Total a pagar', totalPagar, destaque: true),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: carregandoPagamento ? null : abrirPix,
              icon: _metodoPagamentoProcessando == 'PIX'
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pix, size: 25),
              label: const Text(
                'Pagamento PIX',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: carregandoPagamento ? null : abrirAsaas,
              icon: _metodoPagamentoProcessando == 'CARTAO'
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_wallet_outlined, size: 24),
              label: const Text(
                'Pagamento cartão débito ou crédito',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Os pagamentos são processados com segurança pelo Asaas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),

          const SizedBox(height: 12),

          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PoliticaCompraScreen()),
              );
            },
            icon: const Icon(Icons.policy_outlined),
            label: const Text(
              'Política de Compra - Clique aqui',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
