import 'dart:async';

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
import '../../services/cep_service.dart';
import 'pix_pagamento_screen.dart';
import '../dados_pessoais/dados_pessoais_screen.dart';
import '../../services/main_navigation_controller.dart';
import '../../utils/app_snackbar.dart';

class EscolhaPagamentoScreen extends StatefulWidget {
  final Loja loja;

  final double totalProdutos;
  final double totalIngressos;

  final double? taxaConveniencia;
  final double? totalPagar;

  final VoidCallback? onVoltar;
  final int? reservaIngressoId;
  final DateTime? reservaExpiracao;

  const EscolhaPagamentoScreen({
    super.key,
    required this.loja,
    required this.totalProdutos,
    this.totalIngressos = 0,
    this.taxaConveniencia,
    this.totalPagar,
    this.onVoltar,
    this.reservaIngressoId,
    this.reservaExpiracao,
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
  bool falhaConsultaCashback = false;
  Timer? _timerReserva;
  Duration _tempoReservaRestante = Duration.zero;
  bool _reservaExpirada = false;

  bool get carregandoPagamento => _metodoPagamentoProcessando != null;

  String get _tempoReservaFormatado {
    final minutos = _tempoReservaRestante.inMinutes;
    final segundos = _tempoReservaRestante.inSeconds.remainder(60);
    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundos.toString().padLeft(2, '0')}';
  }

  Widget _barraTempoReserva() {
    if (widget.reservaExpiracao == null) return const SizedBox.shrink();
    final urgente = _tempoReservaRestante <= const Duration(minutes: 2);
    final cor = urgente ? Colors.red : Colors.amber.shade800;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tempo para concluir a compra: $_tempoReservaFormatado',
              style: TextStyle(fontWeight: FontWeight.w800, color: cor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.reservaExpiracao != null) {
      _timerReserva = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _atualizarTempoReserva(),
      );
      _atualizarTempoReserva();
    }
    if (widget.reservaIngressoId == null && widget.totalProdutos > 0) {
      _carregarCashback();
    }
  }

  @override
  void dispose() {
    _timerReserva?.cancel();
    super.dispose();
  }

  void _atualizarTempoReserva() {
    final expiracao = widget.reservaExpiracao;
    if (expiracao == null || _reservaExpirada) return;

    final restante = expiracao.difference(DateTime.now());
    final atualizado = restante.isNegative ? Duration.zero : restante;
    if (mounted) setState(() => _tempoReservaRestante = atualizado);
    if (atualizado > Duration.zero) return;

    _reservaExpirada = true;
    _timerReserva?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppSnackBar.aviso(
        context,
        'Sua reserva expirou. Inicie uma nova compra de ingresso.',
      );
      Navigator.pop(context, false);
    });
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
          falhaConsultaCashback = false;
          cashbackUtilizavel =
              double.tryParse('${dados['valor_utilizavel']}') ?? 0;
          saldoCashback = double.tryParse('${dados['saldo_disponivel']}') ?? 0;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          falhaConsultaCashback = true;
          usarCashback = false;
          cashbackUtilizavel = 0;
          saldoCashback = 0;
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
      widget.taxaConveniencia ??
      widget.totalIngressos * (percentualTaxaIngresso / 100);

  double get taxaClubbarTotal => taxaProdutoSplit + taxaIngressoCliente;

  bool get compraDeProdutos => widget.reservaIngressoId == null;

  String get _mensagemPagamentoNaoConcluido => compraDeProdutos
      ? 'Pagamento não concluído. O carrinho foi mantido.'
      : 'Pagamento do ingresso não concluído.';

  String get _mensagemPagamentoNaoConfirmado => compraDeProdutos
      ? 'Pagamento não confirmado. O carrinho foi mantido.'
      : 'Pagamento do ingresso não confirmado.';

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

  Future<void> _mostrarErroPix(Object erro) async {
    final mensagem = apiService.mensagemErroAmigavel(erro);
    final reservaExpirada =
        mensagem.toLowerCase().contains('reserva não está disponível') ||
        mensagem.toLowerCase().contains('reserva de ingressos expirou');
    if (reservaExpirada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sua reserva expirou. Inicie uma nova compra de ingresso.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (erro.toString().toLowerCase().contains('timeout')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A conexão demorou. Antes de gerar outro PIX, confira se a compra apareceu na carteira.',
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }
    final exigeDocumento =
        mensagem.toLowerCase().contains('cpf') ||
        mensagem.toLowerCase().contains('cnpj');
    if (!exigeDocumento) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
      return;
    }

    final atualizar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete seus dados'),
        content: const Text(
          'Para gerar o PIX, o Asaas exige um CPF válido. Atualize seus Dados pessoais e tente novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Agora não'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.badge_rounded),
            label: const Text('Atualizar dados'),
          ),
        ],
      ),
    );
    if (atualizar == true) {
      MainNavigationController.abrirTela(const DadosPessoaisScreen());
    }
  }

  bool _temEnderecoCobrancaCompleto(Map<String, dynamic> perfil) {
    final cep = (perfil['cepcliente'] ?? '').toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return [
          perfil['endcliente'],
          perfil['nrendcliente'],
          perfil['bairrocliente'],
          perfil['cidadecliente'],
          perfil['ufcliente'],
        ].every((campo) => (campo ?? '').toString().trim().isNotEmpty) &&
        cep.length == 8;
  }

  Future<bool> _garantirEnderecoParaCartao() async {
    final perfil = await apiService.buscarMeuPerfil();
    if (_temEnderecoCobrancaCompleto(perfil)) return true;
    if (!mounted) return false;

    final formKey = GlobalKey<FormState>();
    final cepCtrl = TextEditingController(
      text: (perfil['cepcliente'] ?? '').toString(),
    );
    final enderecoCtrl = TextEditingController(
      text: (perfil['endcliente'] ?? '').toString(),
    );
    final numeroCtrl = TextEditingController(
      text: (perfil['nrendcliente'] ?? '').toString(),
    );
    final complementoCtrl = TextEditingController(
      text: (perfil['complcliente'] ?? '').toString(),
    );
    final bairroCtrl = TextEditingController(
      text: (perfil['bairrocliente'] ?? '').toString(),
    );
    final cidadeCtrl = TextEditingController(
      text: (perfil['cidadecliente'] ?? '').toString(),
    );
    final ufCtrl = TextEditingController(
      text: (perfil['ufcliente'] ?? '').toString().toUpperCase(),
    );
    var consultandoCep = false;
    String? ultimoCepConsultado;

    Future<void> buscarCep(StateSetter setSheetState) async {
      final cep = cepCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cep.length != 8 || consultandoCep || cep == ultimoCepConsultado) {
        return;
      }

      setSheetState(() => consultandoCep = true);
      try {
        final endereco = await CepService().buscar(cep);
        if (!mounted) return;

        setSheetState(() {
          ultimoCepConsultado = cep;
          if (endereco.logradouro.isNotEmpty) {
            enderecoCtrl.text = endereco.logradouro;
          }
          if (endereco.bairro.isNotEmpty) {
            bairroCtrl.text = endereco.bairro;
          }
          cidadeCtrl.text = endereco.cidade;
          ufCtrl.text = endereco.uf;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setSheetState(() => consultandoCep = false);
        }
      }
    }

    final salvo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var salvando = false;
        InputDecoration campo(String label, {IconData? icone}) =>
            InputDecoration(
              labelText: label,
              prefixIcon: icone == null ? null : Icon(icone),
              border: const OutlineInputBorder(),
            );

        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Endereço para pagamento com cartão',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Você informa uma vez e o endereço fica salvo para as próximas compras com cartão.',
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: cepCtrl,
                        keyboardType: TextInputType.number,
                        decoration: campo('CEP', icone: Icons.pin_drop_outlined)
                            .copyWith(
                              suffixIcon: consultandoCep
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Buscar CEP',
                                      onPressed: () => buscarCep(setSheetState),
                                      icon: const Icon(Icons.search_rounded),
                                    ),
                            ),
                        onChanged: (value) {
                          final cep = value.replaceAll(RegExp(r'[^0-9]'), '');
                          if (cep != ultimoCepConsultado) {
                            ultimoCepConsultado = null;
                          }
                          if (cep.length == 8) buscarCep(setSheetState);
                        },
                        onFieldSubmitted: (_) => buscarCep(setSheetState),
                        validator: (value) =>
                            value?.replaceAll(RegExp(r'[^0-9]'), '').length == 8
                            ? null
                            : 'Informe um CEP válido',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: enderecoCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: campo(
                          'Logradouro',
                          icone: Icons.signpost_outlined,
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Informe o logradouro'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: numeroCtrl,
                              decoration: campo('Número'),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? 'Informe o número'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: complementoCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: campo('Complemento (opcional)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bairroCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: campo('Bairro'),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Informe o bairro'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: cidadeCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: campo('Cidade'),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? 'Informe a cidade'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: ufCtrl,
                              maxLength: 2,
                              textCapitalization: TextCapitalization.characters,
                              decoration: campo('UF').copyWith(counterText: ''),
                              validator: (value) =>
                                  (value ?? '').trim().length == 2
                                  ? null
                                  : 'UF inválida',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: salvando
                                  ? null
                                  : () => Navigator.pop(sheetContext, false),
                              child: const Text('Agora não'),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: salvando
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      setSheetState(() => salvando = true);
                                      try {
                                        await apiService.salvarEnderecoCobranca(
                                          endereco: enderecoCtrl.text,
                                          numero: numeroCtrl.text,
                                          complemento: complementoCtrl.text,
                                          bairro: bairroCtrl.text,
                                          cep: cepCtrl.text.replaceAll(
                                            RegExp(r'[^0-9]'),
                                            '',
                                          ),
                                          cidade: cidadeCtrl.text,
                                          uf: ufCtrl.text,
                                        );
                                        if (context.mounted) {
                                          Navigator.pop(sheetContext, true);
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                apiService.mensagemErroAmigavel(
                                                  e,
                                                ),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setSheetState(() => salvando = false);
                                        }
                                      }
                                    },
                              icon: salvando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Salvar e continuar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    cepCtrl.dispose();
    enderecoCtrl.dispose();
    numeroCtrl.dispose();
    complementoCtrl.dispose();
    bairroCtrl.dispose();
    cidadeCtrl.dispose();
    ufCtrl.dispose();
    return salvo == true;
  }

  Future<void> abrirPix() async {
    if (_reservaExpirada) return;
    if (totalPagar <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O valor do pagamento deve ser maior que zero.'),
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
      await _mostrarErroPix(e);
    } finally {
      if (mounted) setState(() => _metodoPagamentoProcessando = null);
    }
  }

  Future<void> abrirAsaas() async {
    if (_reservaExpirada) return;
    if (totalPagar <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O valor do pagamento deve ser maior que zero.'),
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

      if (!await _garantirEnderecoParaCartao()) return;

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
            SnackBar(
              content: Text(_mensagemPagamentoNaoConcluido),
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
              SnackBar(
                content: Text(_mensagemPagamentoNaoConfirmado),
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

          // O cartão já apresenta a confirmação no checkout do Asaas.
          // Retornamos ao início sem exibir uma segunda confirmação no app.
          MainNavigationController.irParaHome();
          Navigator.of(context).popUntil((rota) => rota.isFirst);
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;

      final erro = e.toString().toLowerCase();
      final mensagem = erro.contains('timeout')
          ? 'A conexão demorou. Antes de tentar pagar novamente, confira se a compra apareceu na carteira.'
          : erro.contains('reserva não está disponível') ||
                erro.contains('reserva de ingressos expirou')
          ? 'Sua reserva expirou. Inicie uma nova compra de ingresso.'
          : erro.contains('asaas_pendente') ||
                erro.contains('recebimentos ainda') ||
                erro.contains('temporariamente indisponível')
          ? 'Esta compra ainda não pode ser concluída porque o estabelecimento está finalizando a configuração de recebimentos. Tente novamente após a aprovação ou entre em contato com o estabelecimento.'
          : e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
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

          _barraTempoReserva(),

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
                  if (falhaConsultaCashback)
                    TextButton.icon(
                      onPressed: _carregarCashback,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Não foi possível consultar o cashback. Tentar novamente',
                      ),
                    ),
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
                'Pagamento com cartão de crédito',
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
                MaterialPageRoute(
                  builder: (_) => PoliticaCompraScreen(
                    tipo: compraDeProdutos ? 'PRODUTO' : 'INGRESSO',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.policy_outlined),
            label: Text(
              compraDeProdutos
                  ? 'Política de compra de produto'
                  : 'Política de compra de ingresso',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
            child: Text(
              compraDeProdutos
                  ? 'Para cancelamento da compra, acesse Perfil/Minhas compras.'
                  : 'Para cancelamento e alteração de participante, acesse o ingresso em Carteira/Ingressos',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
