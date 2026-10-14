import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ClubbarContactLinks extends StatelessWidget {
  final String emailEstabelecimento;
  final String whatsappEstabelecimento;
  final String emailEvento;
  final String whatsappEvento;
  final bool mostrarContatoEvento;
  final bool centralizado;
  final bool tituloEmNegrito;
  final Color? cor;

  const ClubbarContactLinks({
    super.key,
    required this.emailEstabelecimento,
    required this.whatsappEstabelecimento,
    this.emailEvento = '',
    this.whatsappEvento = '',
    this.mostrarContatoEvento = false,
    this.centralizado = false,
    this.tituloEmNegrito = true,
    this.cor,
  });

  bool get _temContato => [
    emailEstabelecimento,
    whatsappEstabelecimento,
    if (mostrarContatoEvento) emailEvento,
    if (mostrarContatoEvento) whatsappEvento,
  ].any((contato) => contato.trim().isNotEmpty);

  Future<void> _abrir(BuildContext context, Uri uri) async {
    final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abriu && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir este contato.')),
      );
    }
  }

  String _numeroWhatsApp(String telefone) {
    final numeros = telefone.replaceAll(RegExp(r'\D'), '');
    if (numeros.length == 10 || numeros.length == 11) return '55$numeros';
    return numeros;
  }

  Widget _link(
    BuildContext context, {
    required IconData icone,
    required String texto,
    required Uri uri,
  }) {
    return TextButton.icon(
      onPressed: () => _abrir(context, uri),
      icon: Icon(icone, size: 17),
      label: Text(texto, style: const TextStyle(fontWeight: FontWeight.normal)),
      style: TextButton.styleFrom(
        foregroundColor: cor ?? Colors.blue.shade800,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_temContato) return const SizedBox.shrink();

    final emailLoja = emailEstabelecimento.trim();
    final zapLoja = _numeroWhatsApp(whatsappEstabelecimento);
    final emailDoEvento = emailEvento.trim();
    final zapEvento = _numeroWhatsApp(whatsappEvento);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
      child: Align(
        alignment: centralizado ? Alignment.center : Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centralizado
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              'Fale com o organizador/estabelecimento',
              textAlign: centralizado ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: 12,
                fontWeight: tituloEmNegrito
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              alignment: centralizado
                  ? WrapAlignment.center
                  : WrapAlignment.start,
              spacing: 2,
              runSpacing: 2,
              children: [
                if (mostrarContatoEvento && emailDoEvento.isNotEmpty)
                  _link(
                    context,
                    icone: Icons.email_outlined,
                    texto: 'E-mail',
                    uri: Uri(scheme: 'mailto', path: emailDoEvento),
                  )
                else if (emailLoja.isNotEmpty)
                  _link(
                    context,
                    icone: Icons.email_outlined,
                    texto: 'E-mail',
                    uri: Uri(scheme: 'mailto', path: emailLoja),
                  ),
                if (mostrarContatoEvento && zapEvento.isNotEmpty)
                  _link(
                    context,
                    icone: Icons.chat_outlined,
                    texto: 'WhatsApp',
                    uri: Uri.parse('https://wa.me/$zapEvento'),
                  )
                else if (zapLoja.isNotEmpty)
                  _link(
                    context,
                    icone: Icons.chat_outlined,
                    texto: 'WhatsApp',
                    uri: Uri.parse('https://wa.me/$zapLoja'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
