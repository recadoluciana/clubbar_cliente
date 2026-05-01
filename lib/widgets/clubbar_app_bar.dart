import 'package:flutter/material.dart';

class ClubbarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? titulo;
  final bool mostrarCarrinho;
  final int quantidadeCarrinho;
  final VoidCallback? onCarrinhoTap;
  final bool mostrarVersao;

  const ClubbarAppBar({
    super.key,
    this.titulo,
    this.mostrarCarrinho = false,
    this.quantidadeCarrinho = 0,
    this.onCarrinhoTap,
    this.mostrarVersao = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  Widget _badgeCarrinho() {
    if (quantidadeCarrinho <= 0) return const SizedBox();

    return Positioned(
      right: 4,
      top: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
        child: Text(
          quantidadeCarrinho > 99 ? '99+' : '$quantidadeCarrinho',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool temTitulo = titulo != null && titulo!.trim().isNotEmpty;

    return AppBar(
      elevation: 0,
      backgroundColor: temTitulo ? const Color(0xFF050505) : Colors.white,
      centerTitle: true,
      title: temTitulo
          ? Text(
              titulo!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [Image.asset('assets/images/logo.png', height: 120)],
            ),
      actions: [
        if (mostrarCarrinho)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: onCarrinhoTap,
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                _badgeCarrinho(),
              ],
            ),
          )
        else if (mostrarVersao)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                "v1.0.7",
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
