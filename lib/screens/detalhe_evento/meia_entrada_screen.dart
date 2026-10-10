import 'package:flutter/material.dart';

import '../../widgets/clubbar_app_bar.dart';

class MeiaEntradaScreen extends StatelessWidget {
  const MeiaEntradaScreen({super.key});

  static const _texto =
      '''Têm direito à meia-entrada em espetáculos artísticos, culturais, esportivos e de lazer em âmbito nacional os seguintes grupos, conforme a Lei da Meia-Entrada:

• Estudantes: regularmente matriculados em níveis e modalidades previstos na Lei de Diretrizes e Bases da Educação Nacional (infantil, fundamental, médio, técnico, graduação e pós-graduação), mediante apresentação da Carteira de Identificação Estudantil (CIE) padronizada.

• Idosos: pessoas com 60 anos ou mais, mediante apresentação de documento de identidade oficial com foto.

• Pessoas com Deficiência (PcD): e seu acompanhante (quando necessária a companhia), mediante apresentação de cartão de benefício do INSS ou do BPC e documento oficial com foto.

• Jovens de baixa renda: com idade entre 15 e 29 anos, pertencentes a famílias com renda mensal de até dois salários mínimos e inscritos no Cadastro Único (CadÚnico), mediante apresentação da Identidade Jovem (ID Jovem).

Regras Estaduais e Municipais

Além da lei federal, legislações locais e estaduais (como em São Paulo) podem incluir outros grupos, tais como:

• Professores e profissionais da rede pública de ensino (mediante holerite ou carteira funcional).

• Doadores regulares de sangue ou medula óssea (comprovados por carteira oficial do hemocentro).

É obrigatória a apresentação de comprovante na entrada.''';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F6F6),
    appBar: ClubbarAppBar(
      titulo: 'Meia-entrada',
      mostrarVoltar: true,
      mostrarSessao: false,
      mostrarLogo: false,
      onVoltar: () => Navigator.pop(context),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          'Quem tem direito à meia-entrada',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 16),
        SelectableText(_texto, style: TextStyle(fontSize: 16, height: 1.55)),
      ],
    ),
  );
}
