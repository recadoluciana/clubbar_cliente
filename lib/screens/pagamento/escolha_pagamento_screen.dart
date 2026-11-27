import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/explicacao_taxas_ingresso.dart';
import '../../widgets/clubbar_contact_links.dart';
import '../../widgets/prazo_expirado_dialog.dart';
import 'politica_compra_screen.dart';
import 'asaas_checkout_screen.dart';
import 'mercado_pago_card_screen.dart';
import 'mercado_pago_brick_stub.dart'
    if (dart.library.html) 'mercado_pago_brick_web.dart';
import '../../services/cart_badge_notifier.dart';
import '../../services/carteira_badge_notifier.dart';
import '../../services/cep_service.dart';
import 'pix_pagamento_screen.dart';
import '../dados_pessoais/dados_pessoais_screen.dart';
import '../carteira/carteira_screen.dart';
import '../../services/main_navigation_controller.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/cpf_utils.dart';
import '../../utils/horario_brasil.dart';
import '../../core/theme/app_colors.dart';
import '../detalhe_loja/detalhe_loja_screen.dart';

class EscolhaPagamentoScreen extends StatefulWidget {
  final Loja loja;

  final double totalProdutos;
  final double totalIngressos;

  final double? taxaConveniencia;
  final double? totalPagar;

  final VoidCallback? onVoltar;
  final int? reservaIngressoId;
  final DateTime? reservaExpiracao;
  final ApiService? apiService;
  final AuthStorage? authStorage;

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
    this.apiService,
    this.authStorage,
  });

  @override
  State<EscolhaPagamentoScreen> createState() => _EscolhaPagamentoScreenState();
}

class _EscolhaPagamentoScreenState extends State<EscolhaPagamentoScreen> {
  late final ApiService apiService = widget.apiService ?? ApiService();
  late final AuthStorage authStorage = widget.authStorage ?? AuthStorage();

  String? _metodoPagamentoProcessando;
  bool carregandoCashback = false;
  bool usarCashback = false;
  double cashbackUtilizavel = 0;
  double saldoCashback = 0;
  bool falhaConsultaCashback = false;
  String _provedorPagamento = 'ASAAS';
  String? _mercadoPagoPublicKey;
  bool receberNoEndereco = false;
  Map<String, dynamic>? campanhaDoacao;
  Timer? _timerReserva;
  final ValueNotifier<Duration> _tempoReservaNotifier = ValueNotifier(
    Duration.zero,
  );
  DateTime? _reservaExpiracaoAtual;
  Duration _tempoReservaRestante = Duration.zero;
  bool _reservaExpirada = false;
  bool _verificandoReserva = false;
  bool _carregandoResumoIngresso = false;
  bool _erroResumoIngresso = false;
  String? _provedorResumoIngresso;
  Map<String, dynamic>? _cotacaoIngresso;

  bool get carregandoPagamento =>
      _metodoPagamentoProcessando != null ||
      _verificandoReserva ||
      _carregandoResumoIngresso ||
      _erroResumoIngresso ||
      (_reservaExpiracaoAtual != null &&
          _tempoReservaRestante <= Duration.zero);
  bool get _usaMercadoPago => _provedorPagamento == 'MERCADO_PAGO';
  ValueListenable<Duration>? get _tempoReservaParaCheckout =>
      widget.reservaIngressoId != null && _reservaExpiracaoAtual != null
      ? _tempoReservaNotifier
      : null;

  String get _tempoReservaFormatado {
    final minutos = _tempoReservaRestante.inMinutes;
    final segundos = _tempoReservaRestante.inSeconds.remainder(60);
    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundos.toString().padLeft(2, '0')}';
  }

  Widget _barraTempoReserva() {
    if (_reservaExpiracaoAtual == null) return const SizedBox.shrink();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tempo para concluir a compra: $_tempoReservaFormatado',
                  style: TextStyle(fontWeight: FontWeight.w800, color: cor),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Os ingressos ficam reservados durante este prazo. Ao gerar o Pix, o prazo para pagamento será mostrado na próxima tela.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _reservaExpiracaoAtual = widget.reservaExpiracao;
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
    _carregarCampanhaDoacao();
    if (widget.reservaIngressoId != null) {
      _carregarResumoIngresso();
    } else {
      _carregarProvedorPagamento();
    }
  }

  @override
  void dispose() {
    _timerReserva?.cancel();
    _tempoReservaNotifier.dispose();
    super.dispose();
  }

  void _atualizarTempoReserva() {
    final expiracao = _reservaExpiracaoAtual;
    if (expiracao == null || _reservaExpirada) return;

    final restante = expiracao.difference(HorarioBrasil.agora());
    final atualizado = restante.isNegative ? Duration.zero : restante;
    _tempoReservaNotifier.value = atualizado;
    if (mounted) setState(() => _tempoReservaRestante = atualizado);
    if (atualizado > Duration.zero) return;

    _timerReserva?.cancel();
    unawaited(_verificarExpiracaoDaReserva());
  }

  void _sincronizarPrazoReserva(Map<String, dynamic> resposta) {
    if (widget.reservaIngressoId == null || !mounted) return;
    final segundos = int.tryParse('${resposta['segundos_restantes']}');
    final novaExpiracao = segundos != null && segundos >= 0
        ? HorarioBrasil.agora().add(Duration(seconds: segundos))
        : HorarioBrasil.deTextoUtc(resposta['data_expiracao']);
    if (novaExpiracao != null) {
      setState(() => _reservaExpiracaoAtual = novaExpiracao);
      _atualizarTempoReserva();
    }
  }

  Future<void> _verificarExpiracaoDaReserva() async {
    if (_verificandoReserva || widget.reservaIngressoId == null) return;
    if (mounted) setState(() => _verificandoReserva = true);
    try {
      final clienteId = await authStorage.obterClienteId();
      if (clienteId == null) throw Exception('Cliente não identificado.');
      final reserva = await apiService.consultarReserva(
        reservaId: widget.reservaIngressoId!,
        clienteId: clienteId,
      );
      if (!mounted) return;
      final statusPagamento = (reserva['status_pagamento'] ?? '')
          .toString()
          .toUpperCase();
      if (statusPagamento == 'PAGO') {
        _voltarParaLojaComPagamentoConfirmado();
        return;
      }
      if (statusPagamento == 'ESTORNADO') {
        await _encerrarReservaComAviso(PrazoExpiradoTipo.estorno);
        return;
      }
      final segundos = int.tryParse('${reserva['segundos_restantes']}');
      final situacao = (reserva['status'] ?? '').toString().toUpperCase();
      if (segundos != null &&
          segundos > 0 &&
          !{'EXPIRADA', 'CANCELADA'}.contains(situacao)) {
        setState(() {
          _reservaExpiracaoAtual = HorarioBrasil.agora().add(
            Duration(seconds: segundos),
          );
        });
        _atualizarTempoReserva();
        _timerReserva = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _atualizarTempoReserva(),
        );
        return;
      }
      if (!{'EXPIRADA', 'CANCELADA'}.contains(situacao) && segundos == null) {
        throw Exception('Não foi possível confirmar a validade da reserva.');
      }
      await _encerrarReservaComAviso(PrazoExpiradoTipo.reserva);
    } catch (_) {
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'Não foi possível verificar a reserva. Confira sua conexão e tente novamente.',
        );
        _timerReserva = Timer.periodic(
          const Duration(seconds: 10),
          (_) => _atualizarTempoReserva(),
        );
      }
    } finally {
      if (mounted) setState(() => _verificandoReserva = false);
    }
  }

  Future<void> _encerrarReservaComAviso(PrazoExpiradoTipo tipo) async {
    _reservaExpirada = true;
    final navigator = Navigator.of(context);
    final navigatorPrincipal = Navigator.of(context, rootNavigator: true);
    final rotaPrincipal = ModalRoute.of(navigator.context);
    final rotaAtual = ModalRoute.of(context);
    await mostrarPrazoExpirado(context, tipo: tipo);
    if (!mounted) return;
    if (!identical(navigator, navigatorPrincipal)) {
      // Fecha também um checkout aberto por cima do fluxo do evento.
      navigatorPrincipal.popUntil(
        (rota) => rota == rotaPrincipal || rota.isFirst,
      );
    }
    navigator.popUntil((rota) => rota == rotaAtual || rota.isFirst);
    if (mounted && rotaAtual?.isFirst != true) navigator.pop(false);
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

  Future<void> _carregarCampanhaDoacao() async {
    try {
      final campanha = await apiService.campanhaDoacaoVigente(
        lojaId: widget.loja.id,
        reservaIngressoId: widget.reservaIngressoId,
      );
      if (mounted) setState(() => campanhaDoacao = campanha);
    } catch (_) {
      // A campanha é apenas informativa no checkout. Uma indisponibilidade
      // dela não pode impedir o cliente de concluir uma compra.
    }
  }

  Future<void> _carregarProvedorPagamento({bool obrigatorio = false}) async {
    try {
      final dados = await apiService.consultarProvedorPagamentoLoja(
        lojaId: widget.loja.id,
      );
      if (!mounted) return;
      setState(() {
        _provedorPagamento = (dados['provedor_pagamento'] ?? 'ASAAS')
            .toString()
            .toUpperCase();
        if (_provedorPagamento == 'MERCADO_PAGO') {
          _mercadoPagoPublicKey = dados['mercado_pago_public_key']?.toString();
          // O backend ainda mantém a reserva de cashback ligada ao checkout
          // Asaas; não a oferecemos enquanto a compra usar Mercado Pago.
          usarCashback = false;
        }
      });
    } catch (erro) {
      if (obrigatorio) rethrow;
      // Segurança por compatibilidade: se a consulta falhar, preserva Asaas.
    }
  }

  Future<void> _carregarResumoIngresso() async {
    if (!mounted || widget.reservaIngressoId == null) return;
    setState(() {
      _carregandoResumoIngresso = true;
      _erroResumoIngresso = false;
      _cotacaoIngresso = null;
      _provedorResumoIngresso = null;
    });
    try {
      await _carregarProvedorPagamento(obrigatorio: true);
      if (!mounted) return;
      Map<String, dynamic>? cotacao;
      if (_usaMercadoPago) {
        final clienteId = await authStorage.obterClienteId();
        if (clienteId == null || clienteId <= 0) {
          throw Exception('Cliente não identificado');
        }
        cotacao = await apiService.cotarReservaMercadoPago(
          reservaId: widget.reservaIngressoId!,
          clienteId: clienteId,
          metodo: 'PIX',
        );
        for (final campo in ['ingressos', 'conveniencia', 'processamento', 'total', 'percentual_conveniencia']) {
          if (cotacao[campo] is! num) throw Exception('Cotação incompleta');
        }
      }
      if (!mounted) return;
      setState(() {
        _cotacaoIngresso = cotacao;
        _provedorResumoIngresso = _provedorPagamento;
      });
    } catch (_) {
      if (mounted) setState(() => _erroResumoIngresso = true);
    } finally {
      if (mounted) setState(() => _carregandoResumoIngresso = false);
    }
  }

  String get _tituloTaxaConveniencia {
    final cotacao = _cotacaoIngresso;
    if (cotacao == null) return 'Taxa de conveniência';
    if (cotacao['minimo_aplicado'] == true) {
      return 'Taxa de conveniência (mínimo aplicado)';
    }
    final percentual = (cotacao['percentual_conveniencia'] as num).toDouble();
    final texto = percentual.toStringAsFixed(percentual == percentual.truncateToDouble() ? 0 : 2).replaceAll('.', ',');
    return 'Taxa de conveniência ($texto%)';
  }

  Future<void> _validarProvedorDoResumo() async {
    if (widget.reservaIngressoId == null || _provedorResumoIngresso == _provedorPagamento) return;
    await _carregarResumoIngresso();
    throw Exception('O resumo da compra foi atualizado. Confira os valores antes de continuar.');
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

  bool get entregaDisponivel => compraDeProdutos && widget.loja.permiteEntrega;
  bool get entregaSelecionada => entregaDisponivel && receberNoEndereco;

  String get _mensagemPagamentoNaoConcluido => compraDeProdutos
      ? 'Pagamento não concluído. O carrinho foi mantido.'
      : 'Pagamento do ingresso não concluído.';

  String get _mensagemPagamentoNaoConfirmado => compraDeProdutos
      ? 'Pagamento não confirmado. O carrinho foi mantido.'
      : 'Pagamento do ingresso não confirmado.';

  double get cashbackAplicado =>
      compraDeProdutos && !_usaMercadoPago && usarCashback
      ? cashbackUtilizavel
      : 0;

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
    if (reservaExpirada && widget.reservaIngressoId != null) {
      await _verificarExpiracaoDaReserva();
      return;
    }
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
      AppSnackBar.aviso(
        context,
        'A conexão demorou. Antes de gerar outro PIX, confira se a compra apareceu na carteira.',
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

    await _solicitarCpfParaPix();
  }

  Future<void> _solicitarCpfParaPix({bool mostrarEndereco = false}) async {
    final atualizar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete seus dados'),
        content: Text(
          _usaMercadoPago
              ? 'Para gerar o PIX, informe um CPF válido nos seus dados pessoais e tente novamente.'
              : 'Para gerar o PIX, o Asaas exige um CPF válido. Atualize seus dados pessoais e tente novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Agora não'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amareloCerveja,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.badge_rounded),
            label: const Text('Atualizar dados'),
          ),
        ],
      ),
    );
    if (atualizar == true && mounted) {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => DadosPessoaisScreen(
            abertaComoRota: true,
            mostrarEndereco: mostrarEndereco,
          ),
        ),
      );
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

  bool _temCpfValido(Map<String, dynamic> perfil) {
    return CpfUtils.validar(perfil['nrcpfcliente']?.toString());
  }

  Future<bool> _garantirEnderecoParaCartao() async {
    final perfil = await apiService.buscarMeuPerfil();
    if (_temEnderecoCobrancaCompleto(perfil) && _temCpfValido(perfil)) {
      return true;
    }
    if (!mounted) return false;

    final formKey = GlobalKey<FormState>();
    final cepCtrl = TextEditingController(
      text: (perfil['cepcliente'] ?? '').toString(),
    );
    final cpfCtrl = TextEditingController(
      text: CpfUtils.formatar(perfil['nrcpfcliente']?.toString()),
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
                        'Informe seu CPF e endereço. Esses dados ficam salvos para as próximas compras com cartão.',
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: cpfCtrl,
                        keyboardType: TextInputType.number,
                        decoration: campo('CPF', icone: Icons.badge_outlined),
                        onChanged: (value) {
                          final formatado = CpfUtils.formatar(value);
                          if (formatado != value) {
                            cpfCtrl.value = TextEditingValue(
                              text: formatado,
                              selection: TextSelection.collapsed(
                                offset: formatado.length,
                              ),
                            );
                          }
                        },
                        validator: (value) => CpfUtils.validar(value)
                            ? null
                            : 'Informe um CPF válido',
                      ),
                      const SizedBox(height: 12),
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
                                        await apiService.atualizarMeuPerfil(
                                          nome: (perfil['nmcliente'] ?? '')
                                              .toString(),
                                          telefone:
                                              (perfil['nrtelcliente'] ?? '')
                                                  .toString(),
                                          cpf: CpfUtils.somenteNumeros(
                                            cpfCtrl.text,
                                          ),
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

  Future<void> _pagarNaEntrega() async {
    if (!entregaSelecionada || carregandoPagamento) return;
    if (usarCashback) {
      setState(() => usarCashback = false);
      AppSnackBar.info(
        context,
        'O cashback não é aplicado em pedidos pagos na entrega.',
      );
    }
    final perfil = await apiService.buscarMeuPerfil();
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final cep = TextEditingController(text: '${perfil['cepcliente'] ?? ''}');
    final endereco = TextEditingController(
      text: '${perfil['endcliente'] ?? ''}',
    );
    final numero = TextEditingController(
      text: '${perfil['nrendcliente'] ?? ''}',
    );
    final complemento = TextEditingController(
      text: '${perfil['complcliente'] ?? ''}',
    );
    final bairro = TextEditingController(
      text: '${perfil['bairrocliente'] ?? ''}',
    );
    final cidade = TextEditingController(
      text: '${perfil['cidadecliente'] ?? ''}',
    );
    final uf = TextEditingController(text: '${perfil['ufcliente'] ?? ''}');
    final observacao = TextEditingController();

    final dados = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Entrega e pagamento'),
        content: SizedBox(
          width: 420,
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Você pagará ao receber. Confirme o endereço de entrega.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: cep,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'CEP'),
                      validator: (v) =>
                          (v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length ==
                              8
                          ? null
                          : 'CEP inválido',
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: endereco,
                      decoration: const InputDecoration(labelText: 'Endereço'),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Informe o endereço'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: numero,
                      decoration: const InputDecoration(labelText: 'Número'),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Informe o número' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: complemento,
                      decoration: const InputDecoration(
                        labelText: 'Complemento (opcional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: bairro,
                      decoration: const InputDecoration(labelText: 'Bairro'),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Informe o bairro' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cidade,
                            decoration: const InputDecoration(
                              labelText: 'Cidade',
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Informe a cidade'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 64,
                          child: TextFormField(
                            controller: uf,
                            maxLength: 2,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'UF',
                              counterText: '',
                            ),
                            validator: (v) =>
                                (v ?? '').trim().length == 2 ? null : 'UF',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: observacao,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Referência ou observação (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Voltar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, {
                'cep': cep.text.replaceAll(RegExp(r'[^0-9]'), ''),
                'endereco': endereco.text.trim(),
                'numero': numero.text.trim(),
                'complemento': complemento.text.trim(),
                'bairro': bairro.text.trim(),
                'cidade': cidade.text.trim(),
                'uf': uf.text.trim().toUpperCase(),
                'observacao': observacao.text.trim(),
              });
            },
            icon: const Icon(Icons.delivery_dining_rounded),
            label: const Text('Enviar pedido'),
          ),
        ],
      ),
    );
    for (final controller in [
      cep,
      endereco,
      numero,
      complemento,
      bairro,
      cidade,
      uf,
      observacao,
    ]) {
      controller.dispose();
    }
    if (dados == null || !mounted) return;

    setState(() => _metodoPagamentoProcessando = 'ENTREGA');
    try {
      final clienteId = await authStorage.obterClienteId();
      if (clienteId == null) throw Exception('Cliente não identificado.');
      await apiService.criarPedidoEntrega(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        cep: dados['cep']!,
        endereco: dados['endereco']!,
        numero: dados['numero']!,
        complemento: dados['complemento'],
        bairro: dados['bairro']!,
        cidade: dados['cidade']!,
        uf: dados['uf']!,
        observacao: dados['observacao'],
      );
      final quantidade = await apiService.buscarQuantidadeCarrinho(
        clienteId: clienteId,
      );
      CartBadgeNotifier.atualizar(quantidade);
      CarteiraBadgeNotifier.atualizar();
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        'Pedido enviado. Acompanhe o aceite na sua Carteira.',
      );
      MainNavigationController.abrirTela(const CarteiraScreen());
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
      }
    } finally {
      if (mounted) setState(() => _metodoPagamentoProcessando = null);
    }
  }

  Future<Map<String, String>?> _enderecoEntregaDoPerfil() async {
    final perfil = await apiService.buscarMeuPerfil();
    String valor(String campo) => '${perfil[campo] ?? ''}'.trim();
    final endereco = <String, String>{
      'cep': valor('cepcliente').replaceAll(RegExp(r'[^0-9]'), ''),
      'endereco': valor('endcliente'),
      'numero': valor('nrendcliente'),
      'complemento': valor('complcliente'),
      'bairro': valor('bairrocliente'),
      'cidade': valor('cidadecliente'),
      'uf': valor('ufcliente').toUpperCase(),
      'observacao': '',
    };
    final incompleto =
        endereco['cep']!.length != 8 ||
        [
          'endereco',
          'numero',
          'bairro',
          'cidade',
          'uf',
        ].any((campo) => endereco[campo]!.isEmpty) ||
        endereco['uf']!.length != 2;
    if (incompleto) {
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'Para receber o pedido, complete seu endereço em Perfil/Dados pessoais.',
        );
      }
      return null;
    }
    return endereco;
  }

  Future<void> _abrirCheckoutMercadoPago({
    required String metodo,
    required int clienteId,
    Map<String, String>? entrega,
  }) async {
    final valorConfirmado = widget.reservaIngressoId != null
        ? (_cotacaoIngresso?['total'] as num?)?.toDouble()
        : null;
    if (widget.reservaIngressoId != null && valorConfirmado == null) {
      throw Exception('Não foi possível confirmar o resumo da compra. Tente novamente.');
    }
    final valorCheckout = valorConfirmado ?? totalPagar;
    if (metodo.toUpperCase() == 'CREDIT_CARD' && kIsWeb) {
      final publicKey = _mercadoPagoPublicKey;
      if (publicKey == null || publicKey.isEmpty) {
        throw Exception(
          'A chave pública do Mercado Pago não está configurada.',
        );
      }
      if (!mounted) return;
      final dados = await Navigator.of(
        context,
        rootNavigator: true,
      ).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => MercadoPagoBrickScreen(
            publicKey: publicKey,
            amount: valorCheckout,
            permiteParcelamento: false,
            tempoReserva: _tempoReservaParaCheckout,
          ),
        ),
      );
      if (dados == null) return;
      final payer = dados['payer'] is Map
          ? Map<String, dynamic>.from(dados['payer'] as Map)
          : <String, dynamic>{};
      final identification = payer['identification'] is Map
          ? Map<String, dynamic>.from(payer['identification'] as Map)
          : <String, dynamic>{};
      final resposta = widget.reservaIngressoId != null
          ? await apiService.criarCheckoutReservaMercadoPago(
              reservaId: widget.reservaIngressoId!,
              clienteId: clienteId,
              metodo: metodo,
              valorTotalConfirmado: valorConfirmado,
              cardToken: dados['token']?.toString(),
              paymentMethodId: dados['payment_method_id']?.toString(),
              issuerId: dados['issuer_id']?.toString(),
              installments: int.tryParse('${dados['installments']}') ?? 1,
              payerEmail: payer['email']?.toString(),
              payerDocument: identification['number']?.toString(),
            )
          : await apiService.pagarMercadoPago(
              clienteId: clienteId,
              organizacaoId: widget.loja.organizacaoId,
              lojaId: widget.loja.id,
              metodo: metodo,
              percentualTaxaIngresso: percentualTaxaIngresso,
              percentualTaxaProduto: percentualTaxaProduto,
              entrega: entrega,
              cardToken: dados['token']?.toString(),
              paymentMethodId: dados['payment_method_id']?.toString(),
              issuerId: dados['issuer_id']?.toString(),
              installments: int.tryParse('${dados['installments']}'),
              payerEmail: payer['email']?.toString(),
              payerDocument: identification['number']?.toString(),
            );
      await _confirmarMercadoPago(resposta, clienteId);
      return;
    }
    if (metodo.toUpperCase() == 'CREDIT_CARD' && !kIsWeb) {
      final publicKey = _mercadoPagoPublicKey;
      if (publicKey == null || publicKey.isEmpty) {
        throw Exception(
          'A chave pública do Mercado Pago não está configurada.',
        );
      }
      final perfil = await apiService.buscarMeuPerfil();
      if (!mounted) return;
      final tokenizado = await Navigator.of(
        context,
        rootNavigator: true,
      ).push<MercadoPagoCardData>(
        MaterialPageRoute(
          builder: (_) => MercadoPagoCardScreen(
            publicKey: publicKey,
            payerEmail: perfil['emailcliente']?.toString() ?? '',
            payerDocument: perfil['nrcpfcliente']?.toString() ?? '',
            amount: valorCheckout,
            permiteParcelamento: false,
            tempoReserva: _tempoReservaParaCheckout,
          ),
        ),
      );
      if (tokenizado == null) return;
      final clienteToken = await authStorage.obterClienteId();
      if (clienteToken == null || clienteToken == 0) {
        throw Exception('Cliente não identificado');
      }
      final respostaTransparente = widget.reservaIngressoId != null
          ? await apiService.criarCheckoutReservaMercadoPago(
              reservaId: widget.reservaIngressoId!,
              clienteId: clienteToken,
              metodo: metodo,
              valorTotalConfirmado: valorConfirmado,
              cardToken: tokenizado.token,
              paymentMethodId: tokenizado.paymentMethodId,
              issuerId: tokenizado.issuerId,
              installments: tokenizado.installments,
              payerEmail: perfil['emailcliente']?.toString(),
              payerDocument: tokenizado.payerDocument,
            )
          : await apiService.pagarMercadoPago(
              clienteId: clienteToken,
              organizacaoId: widget.loja.organizacaoId,
              lojaId: widget.loja.id,
              metodo: metodo,
              percentualTaxaIngresso: percentualTaxaIngresso,
              percentualTaxaProduto: percentualTaxaProduto,
              entrega: entrega,
              cardToken: tokenizado.token,
              payerEmail: perfil['emailcliente']?.toString(),
              payerDocument: tokenizado.payerDocument,
              paymentMethodId: tokenizado.paymentMethodId,
              issuerId: tokenizado.issuerId,
              installments: tokenizado.installments,
            );
      await _confirmarMercadoPago(respostaTransparente, clienteToken);
      return;
    }
    final resposta = widget.reservaIngressoId != null
        ? await apiService.criarCheckoutReservaMercadoPago(
            reservaId: widget.reservaIngressoId!,
            clienteId: clienteId,
            metodo: metodo,
            valorTotalConfirmado: valorConfirmado,
          )
        : await apiService.pagarMercadoPago(
            clienteId: clienteId,
            organizacaoId: widget.loja.organizacaoId,
            lojaId: widget.loja.id,
            metodo: metodo,
            percentualTaxaIngresso: percentualTaxaIngresso,
            percentualTaxaProduto: percentualTaxaProduto,
            entrega: entrega,
          );
    _sincronizarPrazoReserva(resposta);
    final codigoPix = resposta['pix_copia_cola']?.toString().trim() ?? '';
    if (metodo.toUpperCase() == 'PIX' && codigoPix.isNotEmpty) {
      if (!mounted) return;
      if (widget.reservaIngressoId != null) _timerReserva?.cancel();
      final reservaEncerrada = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PixPagamentoScreen(
            loja: widget.loja,
            pagamento: resposta,
            mercadoPago: true,
            reservaIngressoId: widget.reservaIngressoId,
            clienteId: clienteId,
          ),
        ),
      );
      if (mounted &&
          widget.reservaIngressoId != null &&
          reservaEncerrada == true) {
        _reservaExpirada = true;
        Navigator.pop(context, false);
        return;
      }
      if (mounted && widget.reservaIngressoId != null && !_reservaExpirada) {
        _atualizarTempoReserva();
        if (_tempoReservaRestante > Duration.zero) {
          _timerReserva = Timer.periodic(
            const Duration(seconds: 1),
            (_) => _atualizarTempoReserva(),
          );
        }
      }
      return;
    }
    final checkoutUrl = resposta['checkout_url']?.toString() ?? '';
    if (checkoutUrl.isEmpty) {
      throw Exception('Checkout Mercado Pago não retornado.');
    }
    if (!mounted) return;
    if (kIsWeb) {
      await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_self');
      return;
    }
    final resultado = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(
      MaterialPageRoute(
        builder: (_) => AsaasCheckoutScreen(
          url: checkoutUrl,
          tempoReserva: _tempoReservaParaCheckout,
        ),
      ),
    );
    if (resultado != true || !mounted) {
      if (mounted) {
        AppSnackBar.aviso(context, _mensagemPagamentoNaoConcluido);
      }
      return;
    }
    Map<String, dynamic>? confirmacao;
    for (var tentativa = 0; tentativa < 6; tentativa++) {
      confirmacao = widget.reservaIngressoId != null
          ? await apiService.consultarReserva(
              reservaId: widget.reservaIngressoId!,
              clienteId: clienteId,
            )
          : await apiService.consultarCheckoutMercadoPago(
              preferenceId: resposta['pagamento_id'].toString(),
            );
      if ((confirmacao['status_pagamento'] ?? '').toString().toUpperCase() ==
          'ESTORNADO') {
        if (mounted) await _encerrarReservaComAviso(PrazoExpiradoTipo.estorno);
        return;
      }
      if ((confirmacao['status'] ?? '').toString().toUpperCase() == 'PAGO' ||
          (confirmacao['status_pagamento'] ?? '').toString().toUpperCase() ==
              'PAGO') {
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    final confirmado =
        (confirmacao?['status'] ?? '').toString().toUpperCase() == 'PAGO' ||
        (confirmacao?['status_pagamento'] ?? '').toString().toUpperCase() ==
            'PAGO';
    if (!confirmado) {
      if (mounted) AppSnackBar.aviso(context, _mensagemPagamentoNaoConfirmado);
      return;
    }
    final clienteAtualId = await authStorage.obterClienteId();
    if (clienteAtualId != null && clienteAtualId > 0) {
      CartBadgeNotifier.atualizar(
        await apiService.buscarQuantidadeCarrinho(clienteId: clienteAtualId),
      );
      CarteiraBadgeNotifier.atualizar();
    }
    if (!mounted) return;
    _voltarParaLojaComPagamentoConfirmado();
  }

  void _voltarParaLojaComPagamentoConfirmado() {
    final messenger = ScaffoldMessenger.of(context);
    final navigatorPrincipal = Navigator.of(context, rootNavigator: true);
    MainNavigationController.limparTelasInternas();
    MainNavigationController.abrirTela(DetalheLojaScreen(loja: widget.loja));
    navigatorPrincipal.popUntil((rota) => rota.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messenger.mounted) {
        AppSnackBar.sucessoNoMessenger(
          messenger,
          'Pagamento realizado com sucesso!',
        );
      }
    });
  }

  Future<void> _confirmarMercadoPago(
    Map<String, dynamic> resposta,
    int clienteId,
  ) async {
    final statusInicial = (resposta['status'] ?? '').toString().toUpperCase();
    if (statusInicial == 'REJECTED' || statusInicial == 'CANCELLED') {
      throw Exception(
        'O pagamento não foi aprovado. Confira os dados do cartão ou escolha outra forma de pagamento.',
      );
    }
    Map<String, dynamic>? confirmacao;
    for (var tentativa = 0; tentativa < 6; tentativa++) {
      confirmacao = widget.reservaIngressoId != null
          ? await apiService.consultarReserva(
              reservaId: widget.reservaIngressoId!,
              clienteId: clienteId,
            )
          : await apiService.consultarCheckoutMercadoPago(
              preferenceId: resposta['pagamento_id'].toString(),
            );
      if ((confirmacao['status_pagamento'] ?? confirmacao['status'] ?? '')
              .toString()
              .toUpperCase() ==
          'PAGO') {
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if ((confirmacao?['status_pagamento'] ?? confirmacao?['status'] ?? '')
            .toString()
            .toUpperCase() !=
        'PAGO') {
      throw Exception(_mensagemPagamentoNaoConfirmado);
    }
    CartBadgeNotifier.atualizar(
      await apiService.buscarQuantidadeCarrinho(clienteId: clienteId),
    );
    CarteiraBadgeNotifier.atualizar();
    if (!mounted) return;
    _voltarParaLojaComPagamentoConfirmado();
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
      final perfil = await apiService.buscarMeuPerfil();
      if (!mounted) return;
      if (!_temCpfValido(perfil)) {
        await _solicitarCpfParaPix(
          mostrarEndereco:
              entregaSelecionada && !_temEnderecoCobrancaCompleto(perfil),
        );
        return;
      }
      // A escolha do parceiro pode ter acabado de ser alterada. Atualizamos
      // antes de criar a cobrança para nunca abrir o checkout anterior por
      // causa da consulta assíncrona iniciada no carregamento da tela.
      await _carregarProvedorPagamento(obrigatorio: true);
      await _validarProvedorDoResumo();
      final clienteId = await authStorage.obterClienteId();
      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }
      final entrega = entregaSelecionada
          ? await _enderecoEntregaDoPerfil()
          : null;
      if (entregaSelecionada && entrega == null) return;
      if (_usaMercadoPago) {
        await _abrirCheckoutMercadoPago(
          metodo: 'PIX',
          clienteId: clienteId,
          entrega: entrega,
        );
        return;
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
              entrega: entrega,
            );
      if (!mounted) return;
      if (widget.reservaIngressoId != null) _timerReserva?.cancel();
      final resultadoPix = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PixPagamentoScreen(
            loja: widget.loja,
            pagamento: pagamento,
            reservaIngressoId: widget.reservaIngressoId,
            clienteId: clienteId,
          ),
        ),
      );
      if (mounted &&
          (resultadoPix == false ||
              (widget.reservaIngressoId != null && resultadoPix == true))) {
        if (resultadoPix == true) _reservaExpirada = true;
        Navigator.pop(context, resultadoPix == true ? false : null);
      } else if (mounted &&
          widget.reservaIngressoId != null &&
          !_reservaExpirada) {
        _atualizarTempoReserva();
        if (_tempoReservaRestante > Duration.zero) {
          _timerReserva = Timer.periodic(
            const Duration(seconds: 1),
            (_) => _atualizarTempoReserva(),
          );
        }
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
      // Veja a observação equivalente no fluxo PIX acima.
      await _carregarProvedorPagamento(obrigatorio: true);
      await _validarProvedorDoResumo();
      final clienteId = await authStorage.obterClienteId();

      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }

      if (_usaMercadoPago) {
        final entrega = entregaSelecionada
            ? await _enderecoEntregaDoPerfil()
            : null;
        if (entregaSelecionada && entrega == null) return;
        await _abrirCheckoutMercadoPago(
          metodo: 'CREDIT_CARD',
          clienteId: clienteId,
          entrega: entrega,
        );
        return;
      }

      if (!await _garantirEnderecoParaCartao()) return;
      final entrega = entregaSelecionada
          ? await _enderecoEntregaDoPerfil()
          : null;
      if (entregaSelecionada && entrega == null) return;

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
              entrega: entrega,
            );

      final checkoutUrl = resposta['checkout_url'];
      _sincronizarPrazoReserva(resposta);

      if (checkoutUrl == null || checkoutUrl.toString().isEmpty) {
        throw Exception('Checkout Asaas não retornado.');
      }

      if (!mounted) return;
      if (kIsWeb) {
        await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_self');
      } else {
        final resultado = await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => AsaasCheckoutScreen(
              url: checkoutUrl.toString(),
              tempoReserva: _tempoReservaParaCheckout,
            ),
          ),
        );

        if (resultado != true) {
          if (!mounted) return;
          AppSnackBar.aviso(context, _mensagemPagamentoNaoConcluido);
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
            AppSnackBar.aviso(context, _mensagemPagamentoNaoConfirmado);
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

          // O checkout já confirma o pagamento. Ao voltar ao app, abrimos a
          // mesma loja para que a pessoa continue navegando de onde comprou.
          _voltarParaLojaComPagamentoConfirmado();
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;

      final erro = e.toString().toLowerCase();
      if (widget.reservaIngressoId != null &&
          (erro.contains('reserva não está disponível') ||
              erro.contains('reserva de ingressos expirou'))) {
        await _verificarExpiracaoDaReserva();
        return;
      }
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

  Widget _cartaoCampanhaDoacao() {
    final campanha = campanhaDoacao;
    if (campanha == null) return const SizedBox.shrink();
    final nome = '${campanha['nome'] ?? ''}'.trim();
    final beneficiario = '${campanha['beneficiario'] ?? ''}'.trim();
    final mensagem = '${campanha['mensagem'] ?? ''}'.trim();
    final percentual = double.tryParse('${campanha['percentual_doacao']}') ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        border: Border.all(color: const Color(0xFF8BC9A1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.volunteer_activism_outlined,
            color: Color(0xFF18743A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Para quem doar?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF155D30),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  beneficiario.isEmpty ? nome : '$nome • $beneficiario',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'O estabelecimento destina ${percentual.toStringAsFixed(percentual % 1 == 0 ? 0 : 2)}% do valor líquido recebido a esta campanha.',
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
                if (mensagem.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    mensagem,
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: ClubbarAppBar(
        titulo: 'Pagamento - ${widget.loja.nome}',
        actions: [
          if (widget.reservaIngressoId != null && _reservaExpiracaoAtual != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _tempoReservaFormatado,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
        mostrarVoltar: true,
        mostrarSessao: false,
        onVoltar: widget.onVoltar,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Resumo da compra',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                if (compraDeProdutos) ...[
                  _linhaResumoComIcone(
                    icon: Icons.shopping_bag_outlined,
                    titulo: 'Produtos',
                    valor: widget.totalProdutos,
                  ),
                  const SizedBox(height: 16),
                  _linhaCashback(),
                ] else if (_carregandoResumoIngresso) ...[
                  const Center(child: CircularProgressIndicator()),
                ] else if (_erroResumoIngresso) ...[
                  const Text('Não foi possível carregar o resumo da compra.'),
                  TextButton(onPressed: _carregarResumoIngresso, child: const Text('Tentar novamente')),
                ] else ...[
                  _linhaResumoComIcone(
                    icon: Icons.confirmation_number_outlined,
                    titulo: 'Ingressos',
                    valor: (_cotacaoIngresso?['ingressos'] as num?)?.toDouble() ?? widget.totalIngressos,
                  ),
                  const SizedBox(height: 10),
                  _linhaResumo(_tituloTaxaConveniencia,
                    (_cotacaoIngresso?['conveniencia'] as num?)?.toDouble() ?? taxaIngressoCliente),
                  if (_cotacaoIngresso != null) ...[
                    const SizedBox(height: 10),
                    _linhaResumo('Taxa de processamento (2%)',
                      (_cotacaoIngresso!['processamento'] as num).toDouble()),
                  ],
                ],
                if (compraDeProdutos || (!_carregandoResumoIngresso && !_erroResumoIngresso)) ...[
                  const Divider(height: 28),
                  _linhaResumo(
                    'Total a pagar',
                    (_cotacaoIngresso?['total'] as num?)?.toDouble() ?? totalPagar,
                    destaque: true,
                  ),
                  if (!compraDeProdutos)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => mostrarExplicacaoTaxas(context),
                        child: const Text('Entenda as taxas'),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _barraTempoReserva(),
                if (compraDeProdutos) ...[
                  if (entregaDisponivel) ...[
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: receberNoEndereco,
                      onChanged: carregandoPagamento
                          ? null
                          : (valor) => setState(() => receberNoEndereco = valor),
                      secondary: Icon(
                        receberNoEndereco
                            ? Icons.delivery_dining_rounded
                            : Icons.storefront_outlined,
                        color: Colors.amber.shade800,
                      ),
                      title: Text(
                        receberNoEndereco
                            ? 'Receber no endereço'
                            : 'Retirar no estabelecimento',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        receberNoEndereco
                            ? 'O pedido será enviado após o aceite do estabelecimento.'
                            : 'Ative para solicitar entrega no endereço cadastrado.',
                      ),
                    ),
                  ],
                  if (!_usaMercadoPago && falhaConsultaCashback)
                    TextButton.icon(
                      onPressed: _carregarCashback,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Não foi possível consultar o cashback. Tentar novamente',
                      ),
                    ),
                  if (!_usaMercadoPago &&
                      (carregandoCashback || saldoCashback > 0)) ...[
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
                ],
                if (entregaSelecionada)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      'O estabelecimento confirma o pedido antes de enviá-lo. Você paga ao receber.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                _cartaoCampanhaDoacao(),
                const SizedBox(height: 16),
                Text(
                  _usaMercadoPago
                      ? 'Os pagamentos são processados com segurança pelo Mercado Pago.'
                      : 'Os pagamentos são processados com segurança pelo Asaas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),

                const SizedBox(height: 12),

                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
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
                if (!compraDeProdutos)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(32, 0, 32, 8),
                    child: Text(
                      'Para alterar os participantes, acesse sua Carteira/Ingressos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                if (compraDeProdutos)
                  ClubbarContactLinks(
                    emailEstabelecimento: widget.loja.emailContato,
                    whatsappEstabelecimento: widget.loja.whatsapp,
                    centralizado: true,
                    cor: Theme.of(context).colorScheme.primary,
                    titulo: 'Precisa de ajuda com seu pedido? Fale com o estabelecimento.',
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (entregaSelecionada) ...[
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: carregandoPagamento ? null : _pagarNaEntrega,
                        icon: _metodoPagamentoProcessando == 'ENTREGA'
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delivery_dining_rounded, size: 26),
                        label: const Text(
                          'Pagar na entrega',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F6B3B),
                          side: const BorderSide(
                            color: Color(0xFF0F6B3B),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: carregandoPagamento ? null : abrirPix,
                      icon: _metodoPagamentoProcessando == 'PIX'
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.pix, size: 25),
                      label: const Text(
                        'Pagamento PIX',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B9BD5),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black87,
                              ),
                            )
                          : const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 24,
                            ),
                      label: const Text(
                        'Pagamento com cartão de crédito',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD166),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
