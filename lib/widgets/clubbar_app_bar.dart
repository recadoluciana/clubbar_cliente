import 'package:flutter/material.dart';
import '../services/main_navigation_controller.dart';

class ClubbarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? titulo;
  final bool mostrarCarrinho;
  final int quantidadeCarrinho;
  final VoidCallback? onCarrinhoTap;
  final bool mostrarVersao;
  final bool mostrarVoltar;
  final String logoPath;

  const ClubbarAppBar({
    super.key,
    this.titulo,
    this.mostrarCarrinho = false,
    this.quantidadeCarrinho = 0,
    this.onCarrinhoTap,
    this.mostrarVersao = false,
    this.mostrarVoltar = false,
    this.logoPath = 'assets/images/logo_copa.png',
  });

  // 🔥 AQUI ESTÁ O SEGREDO
  @override
  Size get preferredSize => const Size.fromHeight(80); // 🔥 AUMENTADO

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
      backgroundColor: const Color(0xFF000000),
      foregroundColor: Colors.white,
      centerTitle: true,
      toolbarHeight: 80,

      leading: mostrarVoltar
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                MainNavigationController.irParaHome();
              },
            )
          : null,

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
          : Image.asset(
              logoPath,
              height: 80, // 🔥 AGORA FUNCIONA
              fit: BoxFit.contain,
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
                  color: Colors.white54,
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
