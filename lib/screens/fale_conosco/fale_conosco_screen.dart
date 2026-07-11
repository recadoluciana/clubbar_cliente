import 'package:flutter/material.dart';

import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';

class FaleConoscoScreen extends StatefulWidget {
  const FaleConoscoScreen({super.key});

  @override
  State<FaleConoscoScreen> createState() => _FaleConoscoScreenState();
}

class _FaleConoscoScreenState extends State<FaleConoscoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _assuntoController = TextEditingController();
  final _mensagemController = TextEditingController();

  String categoriaSelecionada = 'DÚVIDA';
  bool enviando = false;

  final List<Map<String, dynamic>> categorias = [
    {
      'codigo': 'DÚVIDA',
      'titulo': 'Dúvida',
      'icone': Icons.help_outline_rounded,
    },
    {
      'codigo': 'PAGAMENTO',
      'titulo': 'Pagamento',
      'icone': Icons.payments_outlined,
    },
    {
      'codigo': 'COMPRA',
      'titulo': 'Compra',
      'icone': Icons.shopping_bag_outlined,
    },
    {
      'codigo': 'INGRESSO',
      'titulo': 'Ingresso',
      'icone': Icons.confirmation_number_outlined,
    },
    {
      'codigo': 'CASHBACK',
      'titulo': 'Cashback',
      'icone': Icons.savings_outlined,
    },
    {'codigo': 'OUTRO', 'titulo': 'Outro', 'icone': Icons.more_horiz_rounded},
  ];

  @override
  void dispose() {
    _assuntoController.dispose();
    _mensagemController.dispose();
    super.dispose();
  }

  InputDecoration _decoracao({
    required String label,
    required IconData icone,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icone),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _categoriaContato(Map<String, dynamic> categoria) {
    final codigo = categoria['codigo'].toString();
    final selecionada = categoriaSelecionada == codigo;

    return InkWell(
      onTap: () {
        setState(() {
          categoriaSelecionada = codigo;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 102,
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selecionada ? Colors.amber : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionada ? Colors.amber.shade700 : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              categoria['icone'] as IconData,
              size: 27,
              color: selecionada ? Colors.black : Colors.grey.shade700,
            ),
            const SizedBox(height: 7),
            Text(
              categoria['titulo'].toString(),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardInformacao({
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: cor),
          ),
          const SizedBox(width: 14),
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

  Future<void> enviarMensagem() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      enviando = true;
    });

    try {
      /*
      Futuramente, substitua este delay por:

      await apiService.enviarFaleConosco(
        categoria: categoriaSelecionada,
        assunto: _assuntoController.text.trim(),
        mensagem: _mensagemController.text.trim(),
      );
      */

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        'Mensagem enviada com sucesso. Em breve entraremos em contato.',
      );

      _assuntoController.clear();
      _mensagemController.clear();

      setState(() {
        categoriaSelecionada = 'DÚVIDA';
      });
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(
        context,
        'Não foi possível enviar sua mensagem. Tente novamente.',
      );
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: const ClubbarAppBar(mostrarVoltar: true),

      body: Column(
        children: [
          const ClubbarPageHeader(
            titulo: 'Fale Conosco',
            subtitulo: 'Estamos prontos para ajudar',
            icone: Icons.support_agent_rounded,
          ),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                children: [
                  const Text(
                    'Como podemos ajudar?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),

                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categorias.map((categoria) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _categoriaContato(categoria),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 22),

                  TextFormField(
                    controller: _assuntoController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoracao(
                      label: 'Assunto',
                      icone: Icons.subject_rounded,
                      hint: 'Informe resumidamente o motivo do contato',
                    ),
                    validator: (value) {
                      final texto = value?.trim() ?? '';

                      if (texto.isEmpty) {
                        return 'Informe o assunto';
                      }

                      if (texto.length < 3) {
                        return 'Assunto muito curto';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _mensagemController,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    minLines: 5,
                    maxLines: 8,
                    maxLength: 1000,
                    decoration: _decoracao(
                      label: 'Mensagem',
                      icone: Icons.chat_bubble_outline_rounded,
                      hint: 'Descreva sua dúvida ou problema com detalhes',
                    ),
                    validator: (value) {
                      final texto = value?.trim() ?? '';

                      if (texto.isEmpty) {
                        return 'Digite sua mensagem';
                      }

                      if (texto.length < 10) {
                        return 'Descreva um pouco melhor sua solicitação';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: enviando ? null : enviarMensagem,
                      icon: enviando
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        enviando ? 'Enviando...' : 'Enviar mensagem',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Atendimento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),

                  const SizedBox(height: 12),

                  _cardInformacao(
                    icone: Icons.schedule_rounded,
                    titulo: 'Horário de atendimento',
                    descricao: 'Segunda a sexta-feira, das 8h às 18h.',
                    cor: Colors.blue,
                  ),

                  const SizedBox(height: 12),

                  _cardInformacao(
                    icone: Icons.mark_email_read_outlined,
                    titulo: 'Prazo de resposta',
                    descricao:
                        'Nossa equipe responderá sua solicitação assim que possível.',
                    cor: Colors.green,
                  ),

                  const SizedBox(height: 12),

                  _cardInformacao(
                    icone: Icons.security_rounded,
                    titulo: 'Seus dados estão seguros',
                    descricao:
                        'As informações enviadas serão utilizadas somente para o atendimento.',
                    cor: Colors.orange,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
