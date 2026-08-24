import 'package:flutter/material.dart';

class FaleConoscoScreen extends StatelessWidget {
  const FaleConoscoScreen({super.key});

  Widget _cardAtendimento({
    required IconData icone,
    required String titulo,
    required String descricao,
    required Color cor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icone, color: cor, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descricao,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 58,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/clubbar_topbar.png',
              height: 29,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'Fale conosco',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _cardAtendimento(
            icone: Icons.schedule_rounded,
            titulo: 'Horário de atendimento',
            descricao: 'Segunda a sexta-feira, das 8h às 18h.',
            cor: Colors.blue,
          ),
          const SizedBox(height: 12),
          _cardAtendimento(
            icone: Icons.mark_email_read_outlined,
            titulo: 'Prazo de resposta',
            descricao:
                'Nossa equipe responderá sua solicitação assim que possível.',
            cor: Colors.green,
          ),
          const SizedBox(height: 12),
          _cardAtendimento(
            icone: Icons.security_rounded,
            titulo: 'Seus dados estão seguros',
            descricao:
                'As informações enviadas serão utilizadas somente para o atendimento.',
            cor: Colors.orange,
          ),
        ],
      ),
    );
  }
}
