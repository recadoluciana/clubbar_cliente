import 'package:flutter/material.dart';

import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/pagbank_web_service.dart';

class CartaoPagamentoScreen extends StatefulWidget {
  final Loja loja;
  final String tipoPagamento; // "CREDIT_CARD" ou "DEBIT_CARD"

  const CartaoPagamentoScreen({
    super.key,
    required this.loja,
    required this.tipoPagamento,
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

  static const String publicKey = 'SUA_PUBLIC_KEY_DO_PAGBANK';

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
        tipoPagamento: widget.tipoPagamento,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento realizado com sucesso')),
      );

      Navigator.pop(context, true);
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
        ? 'Pagamento com débito'
        : 'Pagamento com crédito';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(title: Text(titulo)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nomeCtrl,
              decoration: _decoracao('Nome do portador', Icons.person_outline),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Informe o nome do portador';
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
