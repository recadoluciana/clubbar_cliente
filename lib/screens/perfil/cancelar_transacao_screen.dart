import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/value_formatters.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/perfil_page_header.dart';

class CancelarTransacaoScreen extends StatefulWidget {
  final int vendaId;

  const CancelarTransacaoScreen({super.key, required this.vendaId});

  @override
  State<CancelarTransacaoScreen> createState() =>
      _CancelarTransacaoScreenState();
}

class _CancelarTransacaoScreenState extends State<CancelarTransacaoScreen> {
  final _apiService = ApiService();
  Map<String, dynamic>? _transacao;
  String? _erro;
  bool _carregando = true;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _consultarTransacao();
  }

  Future<void> _consultarTransacao() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _transacao = null;
    });
    try {
      final transacao = await _apiService.consultarCancelamentoTransacao(
        vendaId: widget.vendaId,
      );
      if (mounted) setState(() => _transacao = transacao);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _cancelarTransacao() async {
    if (_transacao == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar cancelamento'),
        content: Text(
          'Deseja cancelar a compra #${widget.vendaId}? Todos os itens serão cancelados e o reembolso total será solicitado pelo mesmo meio de pagamento.',
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
            child: const Text('Confirmar cancelamento'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _cancelando = true);
    try {
      final resultado = await _apiService.cancelarTransacao(
        vendaId: widget.vendaId,
      );
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        resultado['mensagem']?.toString() ??
            'Compra cancelada. O reembolso total foi solicitado.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  Widget _avisoCancelamento() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF0C784)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: Color(0xFF9A6100)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'O cancelamento é sempre da compra inteira. Todos os itens da venda serão cancelados e o valor total será solicitado para reembolso.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _itensCancelamento() {
    final itens = (_transacao!['itens'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final valorTotal =
        double.tryParse('${_transacao!['valor_total'] ?? 0}') ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ...itens.map((item) {
            final ingresso =
                (item['tipo'] ?? '').toString().toUpperCase() == 'INGRESSO';
            final valor = double.tryParse('${item['valor'] ?? 0}') ?? 0;
            return ListTile(
              leading: Icon(
                ingresso
                    ? Icons.confirmation_number_outlined
                    : Icons.shopping_bag_outlined,
                color: ingresso ? Colors.blue : Colors.green,
              ),
              title: Text((item['nome'] ?? 'Item Clubbar').toString()),
              subtitle: Text('${item['quantidade'] ?? 1} unidade(s)'),
              trailing: Text(
                ValueFormatters.moeda(valor),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            );
          }),
          const Divider(height: 1),
          ListTile(
            title: const Text(
              'Total a reembolsar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: Text(
              ValueFormatters.moeda(valorTotal),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F6F6),
    appBar: const ClubbarAppBar(mostrarVoltar: true, mostrarSessao: false),
    body: Column(
      children: [
        const PerfilPageHeader(subtitulo: 'Cancelar compra'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              _avisoCancelamento(),
              const SizedBox(height: 22),
              if (_carregando)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_erro != null) ...[
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _consultarTransacao,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ] else ...[
                Text(
                  'Itens que serão cancelados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _itensCancelamento(),
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
                          ? 'Cancelando compra...'
                          : 'Confirmar cancelamento',
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
