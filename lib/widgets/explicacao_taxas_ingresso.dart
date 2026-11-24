import 'package:material_ui/material_ui.dart';

Widget _itemTaxa(String titulo, String descricao) {
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 14,
          height: 1.4,
        ),
        children: [
          TextSpan(
            text: '$titulo: ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: descricao),
        ],
      ),
    ),
  );
}

void mostrarExplicacaoTaxas(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.74,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: Colors.amber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Entenda nossas taxas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'No Clubbar, os valores aplicáveis são apresentados antes da confirmação do pedido.',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Taxa de conveniência',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              'É o valor destinado à:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            _itemTaxa(
              'Plataforma Clubbar',
              'manutenção, disponibilidade e evolução do site e do aplicativo.',
            ),
            _itemTaxa(
              'Gestão da compra',
              'proteção das informações, emissão do ingresso digital, acompanhamento do pedido e suporte.',
            ),
            _itemTaxa(
              'Recursos do evento',
              'funcionalidades necessárias à venda, conforme a configuração da produção.',
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Taxa de processamento: ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: 'É destinada a: '),
                    TextSpan(
                      text: 'Meio de pagamento: ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: 'Mercado Pago.'),
                  ],
                ),
              ),
            ),
            _itemTaxa(
              'Transação financeira',
              'custos de autorização e operação de cada pagamento.',
            ),
            _itemTaxa(
              'Segurança',
              'tecnologias e controles que protegem os dados e a operação financeira.',
            ),
          ],
        ),
      ),
    ),
  );
}
