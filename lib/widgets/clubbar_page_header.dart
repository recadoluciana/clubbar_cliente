import 'package:flutter/material.dart';

class ClubbarPageHeader extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String? textoAvatar;
  final IconData? icone;
  final Widget? trailing;
  final bool mostrarAba;

  const ClubbarPageHeader({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.textoAvatar,
    this.icone,
    this.trailing,
    this.mostrarAba = true,
  });

  String get _inicial {
    final texto = (textoAvatar ?? titulo).trim();

    if (texto.isEmpty) {
      return '';
    }

    return texto.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD54F), Color(0xFFFFECB3), Color(0xFFF6F6F6)],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.shade200, width: 2),
                ),
                child: icone != null
                    ? Icon(icone, size: 24, color: Colors.black87)
                    : Text(
                        _inicial,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}
