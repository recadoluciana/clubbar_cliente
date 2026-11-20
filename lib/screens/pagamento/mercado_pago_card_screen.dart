import 'package:material_ui/material_ui.dart';
// O SDK PCI ainda recebe os tipos Material do Flutter em sua API pública.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as material_legado;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mercadopago_sdk_flutter/mercadopago_sdk_flutter.dart';

import '../../widgets/reserva_tempo_banner.dart';

class MercadoPagoCardData {
  final String token;
  final String paymentMethodId;
  final String? issuerId;
  final int installments;
  final String payerDocument;
  const MercadoPagoCardData({
    required this.token,
    required this.paymentMethodId,
    this.issuerId,
    required this.installments,
    required this.payerDocument,
  });
}

class MercadoPagoCardScreen extends StatefulWidget {
  final String publicKey;
  final String payerEmail;
  final String payerDocument;
  final double amount;
  final bool permiteParcelamento;
  final ValueListenable<Duration>? tempoReserva;

  const MercadoPagoCardScreen({
    super.key,
    required this.publicKey,
    required this.payerEmail,
    required this.payerDocument,
    required this.amount,
    this.permiteParcelamento = false,
    this.tempoReserva,
  });

  @override
  State<MercadoPagoCardScreen> createState() => _MercadoPagoCardScreenState();
}

class _MercadoPagoCardScreenState extends State<MercadoPagoCardScreen> {
  final _number = PciFieldState();
  final _expiration = PciFieldState();
  final _security = PciFieldState();
  final _name = TextEditingController();
  late final TextEditingController _email;
  late final TextEditingController _document;
  String? _bin;
  PaymentMethod? _method;
  Installment? _plan;
  int _installments = 1;
  bool _loading = false;
  bool _metadataLoading = false;
  String? _error;
  String? _configurationError;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.payerEmail.trim());
    _document = TextEditingController(
      text: widget.payerDocument.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    try {
      final sdk = MercadoPagoSDK.shared;
      if (sdk.isInitialized) {
        sdk.setNewConfiguration(
          publicKey: widget.publicKey,
          countryCode: Country.brazil.code,
          locale: 'pt-BR',
        );
      } else {
        sdk.initialize(
          publicKey: widget.publicKey,
          countryCode: Country.brazil.code,
          locale: 'pt-BR',
        );
      }
    } catch (_) {
      _configurationError =
          'Não foi possível iniciar o pagamento com cartão. Tente novamente.';
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _expiration.dispose();
    _security.dispose();
    _name.dispose();
    _email.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _loadCard(String? bin) async {
    _bin = bin;
    _security.clear();
    setState(() {
      _method = null;
      _plan = null;
      _installments = 1;
      _metadataLoading = bin != null && _configurationError == null;
    });
    if (bin == null || _configurationError != null) return;
    try {
      final methods = await MercadoPagoSDK.shared.coreMethods.getPaymentMethods(
        bin: bin,
      );
      if (!mounted || _bin != bin) return;
      if (methods case Success(:final data)) {
        final cards = data
            .where((m) => m.paymentTypeId == 'credit_card')
            .toList();
        if (cards.isNotEmpty) _method = cards.first;
      }
      if (_method != null && widget.permiteParcelamento) {
        final plans = await MercadoPagoSDK.shared.coreMethods.getInstallments(
          bin: bin,
          amount: widget.amount,
        );
        if (!mounted || _bin != bin) return;
        if (plans case Success(:final data)) {
          final matches = data.where(
            (p) =>
                p.paymentMethodId == _method!.id &&
                p.paymentTypeId == 'credit_card',
          );
          if (matches.isNotEmpty) {
            _plan = matches.first;
            if (_plan!.payerCosts.isNotEmpty &&
                !_plan!.payerCosts.any((cost) => cost.installments == 1)) {
              _installments = _plan!.payerCosts.first.installments;
            }
          }
        }
      }
    } catch (_) {
      // A subsequent submission explains that the card could not be identified.
    } finally {
      if (mounted && _bin == bin) {
        setState(() {
          _metadataLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_loading || _metadataLoading) return;
    final email = _email.text.trim();
    final cpf = _document.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_name.text.trim().isEmpty || cpf.length != 11 || !email.contains('@')) {
      setState(
        () => _error = 'Informe nome, e-mail e CPF do titular do cartão.',
      );
      return;
    }
    final method = _method;
    if (method == null) {
      setState(
        () => _error = 'Não foi possível identificar a bandeira do cartão. Confira o número e tente novamente.',
      );
      return;
    }
    // A tokenização bem-sucedida limpa os campos PCI e dispara onBinChanged,
    // que reseta os metadados da tela. Preserve a seleção desta submissão.
    final issuerId = _plan?.issuer.id;
    final installments = _installments;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await MercadoPagoSDK.shared.coreMethods
          .createTokenForNewCard(
            cardNumber: _number,
            expirationDate: _expiration,
            securityCode: _security,
            identification: BuyerIdentification(
              name: _name.text.trim(),
              type: 'CPF',
              number: cpf,
            ),
          );
      if (!mounted) return;
      if (result case Success(:final data)) {
        Navigator.pop(
          context,
          MercadoPagoCardData(
            token: data.token,
            paymentMethodId: method.id,
            issuerId: issuerId,
            installments: installments,
            payerDocument: cpf,
          ),
        );
      } else {
        setState(
          () => _error = 'Não foi possível validar o cartão. Confira os dados e tente novamente.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível concluir a validação do cartão. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _campoPci(Widget campo) => MaterialUiCompatibilityBridge(
    child: material_legado.Material(
      type: material_legado.MaterialType.transparency,
      child: campo,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final costs = _plan?.payerCosts ?? const <PayerCost>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento com cartão')),
      body: Column(
        children: [
          if (widget.tempoReserva != null)
            ReservaTempoBanner(tempo: widget.tempoReserva!),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Cartão de crédito',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _campoPci(
                  CardNumberField(
                    controller: _number,
                    label: 'Número do cartão',
                    onBinChanged: _loadCard,
                    enabled: !_loading,
                    decoration: const material_legado.InputDecoration(
                      border: material_legado.OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _campoPci(
                  ExpirationDateField(
                    controller: _expiration,
                    label: 'Validade',
                    hintText: 'MM/AA',
                    enabled: !_loading,
                    decoration: const material_legado.InputDecoration(
                      border: material_legado.OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _campoPci(
                  SecurityCodeField(
                    controller: _security,
                    label: 'Código de segurança',
                    enabled: !_loading,
                    expectedLength: _method?.securityCodeLength,
                    decoration: const material_legado.InputDecoration(
                      border: material_legado.OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  enabled: !_loading,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Nome no cartão',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _document,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'CPF do titular do cartão',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (widget.permiteParcelamento && costs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _installments,
                    decoration: const InputDecoration(
                      labelText: 'Parcelas',
                      border: OutlineInputBorder(),
                    ),
                    items: costs
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.installments,
                            child: Text(
                              '${c.installments}x de R\$ ${c.installmentAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _installments = v ?? 1),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed:
                      _loading ||
                          _metadataLoading ||
                          _configurationError != null
                      ? null
                      : _submit,
                  child: Text(
                    _loading
                        ? 'Validando cartão...'
                        : _metadataLoading
                        ? 'Identificando cartão...'
                        : 'Pagar com cartão',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_configurationError != null || _error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _configurationError ?? _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
