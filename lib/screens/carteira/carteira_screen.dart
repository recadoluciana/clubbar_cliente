import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/carteira_item.dart';
import '../../models/loja.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';

class CarteiraScreen extends StatefulWidget {
  const CarteiraScreen({super.key});

  @override
  State<CarteiraScreen> createState() => _CarteiraScreenState();
}

class _CarteiraScreenState extends State<CarteiraScreen> {
  final apiService = ApiService();
  final authStorage = AuthStorage();

  bool carregando = true;
  String? erro;

  int? clienteId;
  int? lojaSelecionadaId;

  List<Loja> lojas = [];
  List<CarteiraItem> itensCarteira = [];

  @override
  void initState() {
    super.initState();
    carregarTela();
  }

  Future<void> carregarTela() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final idCliente = await authStorage.obterClienteId();

      if (idCliente == null || idCliente == 0) {
        throw Exception('Cliente não identificado. Faça login novamente.');
      }

      clienteId = idCliente;

      lojas = await apiService.buscarLojas();

      if (lojas.isEmpty) {
        setState(() {
          itensCarteira = [];
          carregando = false;
        });
        return;
      }

      lojaSelecionadaId ??= lojas.first.id;

      await carregarCarteiraDaLoja();
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  Future<void> carregarCarteiraDaLoja() async {
    if (clienteId == null || lojaSelecionadaId == null) return;

    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final itens = await apiService.buscarCarteira(
        clienteId: clienteId!,
        lojaId: lojaSelecionadaId!,
      );

      setState(() {
        itensCarteira = itens;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        itensCarteira = [];
        carregando = false;
      });
    }
  }

  String get nomeLojaSelecionada {
    if (lojaSelecionadaId == null) return 'Loja';
    final loja = lojas.firstWhere(
      (l) => l.id == lojaSelecionadaId,
      orElse: () => Loja(
        id: 0,
        organizacaoId: 0,
        nome: 'Loja',
        bairro: '',
        horario: '',
        imagemUrl: '',
        instagram: '',
      ),
    );
    return loja.nome;
  }

  void abrirQrOuRetirada(String codigo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Retirada do pedido',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Apresente este QR Code no balcão',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // 🔥 QR CODE
                QrImageView(
                  data: codigo,
                  size: 220,
                  backgroundColor: Colors.white,
                ),

                const SizedBox(height: 16),

                Text(
                  codigo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconePorTipo(String tipo) {
    final t = tipo.toUpperCase();

    if (t.contains('INGRESSO') || t.contains('E')) {
      return Icons.confirmation_number_outlined;
    }

    if (t.contains('P')) {
      return Icons.local_bar_outlined;
    }

    return Icons.inventory_2_outlined;
  }

  Widget _cabecalho() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111111), Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 36,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Minha carteira',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Itens disponíveis para uso ou retirada na loja selecionada.',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seletorLoja() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: lojaSelecionadaId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(18),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: lojas.map((loja) {
            return DropdownMenuItem<int>(
              value: loja.id,
              child: Text(loja.nome),
            );
          }).toList(),
          onChanged: (valor) async {
            if (valor == null) return;

            setState(() {
              lojaSelecionadaId = valor;
            });

            await carregarCarteiraDaLoja();
          },
        ),
      ),
    );
  }

  Widget _cardResumo() {
    final totalUnidades = itensCarteira.fold<int>(
      0,
      (total, item) => total + item.quantidade,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              itensCarteira.isEmpty
                  ? 'Nenhum item disponível em $nomeLojaSelecionada'
                  : '$totalUnidades item(ns) disponível(is) em $nomeLojaSelecionada',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardItem(CarteiraItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => abrirQrOuRetirada(item),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.local_bar_outlined,
                    color: Colors.amber.shade800,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.titulo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Disponível',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.descricao.isEmpty
                            ? 'Disponível para retirada'
                            : item.descricao,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chipInfo('Qtd: ${item.quantidade}'),
                          if (item.dataCriacao.isNotEmpty)
                            _chipInfo('Compra: ${item.dataCriacao}'),
                          if (item.dataExpiracao.isNotEmpty)
                            _chipInfo('Validade: ${item.dataExpiracao}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'R\$ ${item.valorUnitario.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => abrirQrOuRetirada(item),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: const Text('Retirar'),
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
      ),
    );
  }

  Widget _estadoVazio() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Sua carteira está vazia nesta loja',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecione outra loja ou faça uma nova compra para visualizar itens aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _erroWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 56),
          const SizedBox(height: 14),
          Text(
            erro ?? 'Erro ao carregar carteira',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: carregarTela,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _chipInfo(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                _cabecalho(),
                const SizedBox(height: 20),
                const Text(
                  'Loja selecionada',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (lojas.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text('Nenhuma loja disponível para seleção.'),
                  )
                else
                  _seletorLoja(),
                const SizedBox(height: 16),
                _cardResumo(),
                const SizedBox(height: 22),
                const Text(
                  'Itens disponíveis',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                if (erro != null)
                  _erroWidget()
                else if (itensCarteira.isEmpty)
                  _estadoVazio()
                else
                  ...itensCarteira.map(_cardItem),
              ],
            ),
    );
  }
}
