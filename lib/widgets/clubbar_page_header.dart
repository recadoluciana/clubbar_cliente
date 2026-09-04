import 'package:flutter/material.dart';

class ClubbarPageHeader extends StatelessWidget {
  final String titulo;
  final String subtitulo;

  // Conteúdo do lado esquerdo
  final String? textoAvatar;
  final IconData? icone;
  final String? imagemAvatarUrl;
  final double tamanhoAvatar;
  final bool mostrarAvatar;
  final Color? corTitulo;

  // Conteúdo opcional do lado direito
  final Widget? trailing;
  final String? imagemUrl;

  // Mantido para não quebrar chamadas antigas
  final bool mostrarAba;

  const ClubbarPageHeader({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.textoAvatar,
    this.icone,
    this.imagemAvatarUrl,
    this.tamanhoAvatar = 48,
    this.mostrarAvatar = true,
    this.corTitulo,
    this.trailing,
    this.imagemUrl,
    this.mostrarAba = false,
  });

  String get _inicial {
    final texto = (textoAvatar ?? titulo).trim();

    if (texto.isEmpty) {
      return '';
    }

    return texto.substring(0, 1).toUpperCase();
  }

  /// Ícone ou inicial exibido sempre do lado esquerdo.
  Widget _avatarEsquerdo() {
    final avatarUrl = imagemAvatarUrl?.trim() ?? '';

    return Container(
      width: tamanhoAvatar,
      height: tamanhoAvatar,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber.shade200, width: 2),
      ),
      child: ClipOval(
        child: avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                width: tamanhoAvatar,
                height: tamanhoAvatar,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  icone ?? Icons.storefront_rounded,
                  size: 24,
                  color: Colors.black87,
                ),
              )
            : icone != null
            ? Icon(icone, size: 24, color: Colors.black87)
            : Text(
                _inicial,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  /// Logo opcional exibida somente do lado direito.
  Widget _logoDireita() {
    final url = imagemUrl?.trim() ?? '';

    if (url.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return const Center(
              child: Icon(
                Icons.storefront_rounded,
                color: Colors.black87,
                size: 26,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFFFECB3), Color(0xFFF6F6F6)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (mostrarAvatar) ...[_avatarEsquerdo(), const SizedBox(width: 12)],

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: corTitulo,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ] else if (imagemUrl != null && imagemUrl!.trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            _logoDireita(),
          ],
        ],
      ),
    );
  }
}
