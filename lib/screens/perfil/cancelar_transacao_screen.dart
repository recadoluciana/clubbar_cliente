import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/value_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/perfil_page_header.dart';

class CancelarTransacaoScreen extends StatefulWidget {
  const CancelarTransacaoScreen({super.key});

  @override
  State<CancelarTransacaoScreen> createState() =>
      _CancelarTransacaoScreenState();
}

class _CancelarTransacaoScreenState extends State<CancelarTransacaoScreen> {
  final _vendaController = TextEditingController();
  final _apiService = ApiService();
  Map<String, dynamic>? _transacao;
  bool _consultando = false;
  bool _cancelando = false;

  @override
  void dispose() {
    _vendaController.dispose();
    super.dispose();
  }

  Future<void> _cancelarTransacao() async {
    final vendaId = int.tryParse(_vendaController.text.trim());
    if (vendaId == null || vendaId <= 0) {
      AppSnackBar.aviso(context, 'Informe um número de venda válido.');
      return;
    }
    if (_transacao == null || _transacao!['venda_id'] != vendaId) {
      AppSnackBar.aviso(
        context,
        'Consulte os itens da transação antes de cancelar.',
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar transação'),
        content: Text(
          'Deseja cancelar a transação #$vendaId? Todos os produtos e ingressos dessa venda serão cancelados e o reembolso total será solicitado pelo mesmo meio de pagamento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar transação'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _cancelando = true);
    try {
      final resultado = await _apiService.cancelarTransacao(vendaId: vendaId);
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        resultado['mensagem']?.toString() ??
            'Transação cancelada. O reembolso total foi solicitado.',
      );
      _vendaController.clear();
      setState(() => _transacao = null);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  Future<void> _consultarTransacao() async {
    final vendaId = int.tryParse(_vendaController.text.trim());
    if (vendaId == null || vendaId <= 0) {
      AppSnackBar.aviso(context, 'Informe um número de venda válido.');
      return;
    }

    setState(() {
      _consultando = true;
      _transacao = null;
    });
    try {
      final transacao = await _apiService.consultarCancelamentoTransacao(
        vendaId: vendaId,
      );
      if (mounted) setState(() => _transacao = transacao);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true, mostrarSessao: false),
      body: Column(
        children: [
          const PerfilPageHeader(subtitulo: 'Cancelar transação'),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF0C784)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF9A6100),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'O cancelamento é sempre da transação inteira. Todos os itens da venda serão cancelados e o valor total será solicitado para reembolso.',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _vendaController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_transacao != null) setState(() => _transacao = null);
                  },
                  onSubmitted: (_) => _consultarTransacao(),
                  decoration: InputDecoration(
                    labelText: 'Número da transação',
                    hintText: 'Ex.: 265',
                    prefixIcon: const Icon(Icons.receipt_long_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Você encontra este número na sua Carteira, identificado como “Venda: #”.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _consultando ? null : _consultarTransacao,
                    icon: _consultando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(
                      _consultando
                          ? 'Consultando transação...'
                          : 'Ver itens da transação',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                if (_transacao != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Itens que serão cancelados',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        ...((_transacao!['itens'] as List? ?? [])
                            .whereType<Map>()
                            .map((item) {
                              final dados = Map<String, dynamic>.from(item);
                              final ingresso =
                                  (dados['tipo'] ?? '')
                                      .toString()
                                      .toUpperCase() ==
                                  'INGRESSO';
                              final valor =
                                  double.tryParse('${dados['valor'] ?? 0}') ??
                                  0;
                              return ListTile(
                                leading: Icon(
                                  ingresso
                                      ? Icons.confirmation_number_outlined
                                      : Icons.shopping_bag_outlined,
                                  color: ingresso ? Colors.blue : Colors.green,
                                ),
                                title: Text(
                                  (dados['nome'] ?? 'Item Clubbar').toString(),
                                ),
                                subtitle: Text(
                                  'Item #${dados['itvenda_id']} · ${dados['quantidade']} unidade(s)',
                                ),
                                trailing: Text(
                                  ValueFormatters.moeda(valor),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            })),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text(
                            'Total a reembolsar',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          trailing: Text(
                            ValueFormatters.moeda(
                              double.tryParse(
                                    '${_transacao!['valor_total'] ?? 0}',
                                  ) ??
                                  0,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _cancelando ? null : _cancelarTransacao,
                      icon: _cancelando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cancel_outlined),
                      label: Text(
                        _cancelando
                            ? 'Cancelando transação...'
                            : 'Cancelar todos os itens',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
