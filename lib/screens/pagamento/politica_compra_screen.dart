import 'package:flutter/material.dart';
import '../../widgets/clubbar_app_bar.dart';

class PoliticaCompraScreen extends StatelessWidget {
  const PoliticaCompraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        onVoltar: () => Navigator.pop(context),
      ),
      backgroundColor: const Color(0xFFF6F6F6),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            'Política de Compra',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 18),

          Text(
            'Compra de Produtos e Ingressos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Ao realizar uma compra pelo Clubbar, o cliente declara estar ciente das condições de uso, retirada, consumo e validade dos produtos e ingressos adquiridos.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),

          SizedBox(height: 24),
          Text(
            'Cancelamento',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Solicitações de cancelamento devem respeitar as regras do estabelecimento, do evento e da legislação aplicável. Compras já utilizadas, retiradas ou consumidas não poderão ser canceladas.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),

          SizedBox(height: 24),
          Text(
            'Alteração de participante no ingresso',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'A alteração do participante poderá ser permitida antes da utilização do ingresso, desde que respeitadas as regras do evento e mediante validação dos dados do novo participante.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}
