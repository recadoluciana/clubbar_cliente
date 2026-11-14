import 'package:flutter/material.dart';

class TermosUsoScreen extends StatelessWidget {
  const TermosUsoScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Termos de Uso')),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: SelectableText(
          '''Termos de Uso do Clubbar

O Clubbar permite consultar estabelecimentos e eventos, adquirir produtos e ingressos, acessar compras e usar outras funcionalidades disponíveis na plataforma.

1. Cadastro e acesso
Forneça informações corretas e atualizadas e mantenha suas credenciais protegidas. Você é responsável pelas atividades realizadas em sua conta e deve comunicar ao Clubbar qualquer acesso não autorizado.

2. Ofertas e compras
Confira os produtos, ingressos, preços, taxas, disponibilidade e condições antes de concluir a compra. As informações de estabelecimentos e eventos são fornecidas pelos respectivos parceiros e podem mudar até a confirmação do pedido.

3. Pagamentos e carteira
Os pagamentos são processados por provedores de pagamento. A disponibilização de produtos e ingressos na carteira depende da confirmação do pagamento e das condições aplicáveis. Apresente o comprovante ou QR Code quando solicitado pelo estabelecimento.

4. Cancelamentos e reembolsos
As condições de cancelamento e reembolso são apresentadas no fluxo de compra e devem ser consultadas antes da contratação, sem prejuízo dos direitos previstos na legislação. Em caso de dúvida, entre em contato pelos canais informados no aplicativo.

5. Promoções e cortesias
Ofertas e cortesias podem ter prazo, quantidade limitada e regras próprias, informadas na oferta. A disponibilidade pode mudar ou se esgotar.

6. Uso da plataforma
Não utilize o Clubbar para fraude, uso indevido de credenciais, violação de direitos de terceiros ou outras atividades ilegais. O acesso poderá ser restringido em situações de uso indevido, respeitada a legislação aplicável.

7. Privacidade e comunicações
O tratamento de dados pessoais é explicado na Política de Privacidade, disponível na tela de login. Preferências de notificações e e-mails podem ser consultadas no perfil, quando disponíveis.

8. Disponibilidade e alterações
Podemos atualizar funcionalidades e estes termos. Alterações relevantes serão comunicadas pelos canais disponíveis. Interrupções temporárias podem ocorrer para manutenção ou por problemas de serviços de terceiros.

9. Atendimento
Para dúvidas sobre a plataforma, entre em contato pelo e-mail suporte@clubbar.com.br. Para dúvidas específicas de uma compra ou evento, consulte também os canais do estabelecimento apresentados no aplicativo.''',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
      ),
    ),
  );
}
