import 'package:flutter/material.dart';

import '../services/auth_storage.dart';
import 'clubbar_page_header.dart';

class PerfilPageHeader extends StatefulWidget {
  final String subtitulo;
  final Widget? conteudoInferior;

  const PerfilPageHeader({
    super.key,
    required this.subtitulo,
    this.conteudoInferior,
  });

  @override
  State<PerfilPageHeader> createState() => _PerfilPageHeaderState();
}

class _PerfilPageHeaderState extends State<PerfilPageHeader> {
  late final Future<String> _nomeCliente;

  @override
  void initState() {
    super.initState();
    _nomeCliente = AuthStorage().obterNmcliente().then((nome) {
      final nomeLimpo = nome?.trim() ?? '';
      return nomeLimpo.isEmpty ? 'Cliente Clubbar' : nomeLimpo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _nomeCliente,
      builder: (context, snapshot) => ClubbarPageHeader(
        titulo: snapshot.data ?? 'Cliente Clubbar',
        subtitulo: widget.subtitulo,
        mostrarAvatar: false,
        corTitulo: Colors.blue.shade700,
        conteudoInferior: widget.conteudoInferior,
      ),
    );
  }
}
