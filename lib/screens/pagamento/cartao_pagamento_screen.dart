import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/pagbank_web_service.dart';
import 'pagamento_sucesso_screen.dart';
import '../carteira/carteira_screen.dart';

class CartaoPagamentoScreen extends StatefulWidget {
  final Loja loja;
  final String tipoPagamento;
  final double totalProdutos;
  final double taxaConveniencia;
  final double totalPagar;

  const CartaoPagamentoScreen({
    super.key,
    required this.loja,
    required this.tipoPagamento,
    required this.totalProdutos,
    required this.taxaConveniencia,
    required this.totalPagar,
  });

  @override
  State<CartaoPagamentoScreen> createState() => _CartaoPagamentoScreenState();
}

class _CartaoPagamentoScreenState extends State<CartaoPagamentoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _mesCtrl = TextEditingController();
  final _anoCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = false;

  static const String publicKey =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAr+ZqgD892U9/HXsa7XqBZUayPquAfh9xx4iwUbTSUAvTlmiXFQNTp0Bvt/5vK2FhMj39qSv1zi2OuBjvW38q1E374nzx6NNBL5JosV0+SDINTlCG0cmigHuBOyWzYmjgca+mtQu4WczCaApNaSuVqgb8u7Bd9GCOL4YJotvV5+81frlSwQXralhwRzGhj/A57CGPgGKiuPT+AOGmykIGEZsSD9RKkyoKIoc0OS8CPIzdBOtTQCIwrLn2FxI83Clcg55W8gkFSOS6rWNbG5qFZWMll6yl02HtunalHmUlRUL66YeGXdMDC2PuRcmZbGO5a/2tbVppW6mfSWG3NPRpgwIDAQAB';

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _numeroCtrl.dispose();
    _mesCtrl.dispose();
    _anoCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Widget _linhaResumo(String titulo, double valor, {bool destaque = false}) {
    final estilo = TextStyle(
      fontSize: destaque ? 18 : 15,
      fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
      color: destaque ? Colors.black : Colors.grey.shade800,
    );

    return Row(
      children: [
        Expanded(child: Text(titulo, style: estilo)),
        Text('R\$ ${valor.toStringAsFixed(2)}', style: estilo),
      ],
    );
  }

  Widget _resumoPagamento() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo do pagamento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          _linhaResumo('Total produtos', widget.totalProdutos),
          const SizedBox(height: 8),
          _linhaResumo('Taxa de conveniência', widget.taxaConveniencia),
          const Divider(height: 24),
          _linhaResumo('Total a pagar', widget.totalPagar, destaque: true),
        ],
      ),
    );
  }

  Widget _dadosCartaoBox() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dados do cartão',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nomeCtrl,
            decoration: _decoracao('Nome do titular', Icons.person_outline),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Informe o nome do titular';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _numeroCtrl,
            keyboardType: TextInputType.number,
            decoration: _decoracao('Número do cartão', Icons.credit_card),
            validator: (value) {
              final n = _somenteNumeros(value ?? '');
              if (n.length < 13) return 'Número do cartão inválido';
              return null;
            },
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _mesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _decoracao('Mês', Icons.date_range),
                  validator: (value) {
                    final v = int.tryParse(value ?? '');
                    if (v == null || v < 1 || v > 12) {
                      return 'Mês inválido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: TextFormField(
                  controller: _anoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _decoracao('Ano', Icons.event),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length != 4) return 'Ano inválido';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: TextFormField(
                  controller: _cvvCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _decoracao('CVV', Icons.lock_outline),
                  validator: (value) {
                    final n = _somenteNumeros(value ?? '');
                    if (n.length < 3 || n.length > 4) {
                      return 'CVV inválido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> pagar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      carregando = true;
    });

    try {
      final clienteId = await authStorage.obterClienteId();
      if (clienteId == null || clienteId == 0) {
        throw Exception('Cliente não identificado');
      }

      final result = PagBankWebService.encryptCard(
        publicKey: publicKey,
        holder: _nomeCtrl.text.trim(),
        number: _somenteNumeros(_numeroCtrl.text),
        expMonth: _mesCtrl.text.trim(),
        expYear: _anoCtrl.text.trim(),
        securityCode: _somenteNumeros(_cvvCtrl.text),
      );

      if (result.hasErrors || result.encryptedCard.isEmpty) {
        throw Exception(
          result.errors.isNotEmpty
              ? result.errors.join(', ')
              : 'Não foi possível criptografar o cartão',
        );
      }

      await apiService.pagarComCartao(
        clienteId: clienteId,
        organizacaoId: widget.loja.organizacaoId,
        lojaId: widget.loja.id,
        encryptedCard: result.encryptedCard,
        securityCode: _somenteNumeros(_cvvCtrl.text),
        tipoPagamento: widget.tipoPagamento,
      );

      if (!mounted) return;

      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PagamentoSucessoScreen()),
      );

      if (resultado == true && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CarteiraScreen()),
        );
        return;
      }

      if (!mounted) return;

      Navigator.pop(context, false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  InputDecoration _decoracao(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.tipoPagamento == 'DEBIT_CARD'
        ? 'Pagamento com cartão de débito'
        : 'Pagamento com cartão de crédito';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(title: Text(titulo)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _resumoPagamento(),
            const SizedBox(height: 20),

            _dadosCartaoBox(),
            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: carregando ? null : pagar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: carregando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Finalizar pagamento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
