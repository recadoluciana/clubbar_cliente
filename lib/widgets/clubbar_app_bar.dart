import 'package:flutter/material.dart';
import '../services/main_navigation_controller.dart';

class ClubbarBrandLogo extends StatelessWidget {
  final double owlHeight;

  const ClubbarBrandLogo({super.key, this.owlHeight = 40});

  @override
  Widget build(BuildContext context) {
    final wordmarkHeight = owlHeight * 0.45;
    return SizedBox(
      height: owlHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/corujao.png',
            height: owlHeight,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          Padding(
            padding: EdgeInsets.only(top: owlHeight * 0.10),
            child: Image.asset(
              'assets/images/clubbar_wordmark_white.png',
              height: wordmarkHeight,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class ClubbarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? titulo;
  final bool mostrarCarrinho;
  final int quantidadeCarrinho;
  final VoidCallback? onCarrinhoTap;
  final bool mostrarVersao;
  final bool mostrarVoltar;
  final String logoPath;
  final VoidCallback? onVoltar;
  final List<Widget> actions;

  const ClubbarAppBar({
    super.key,
    this.titulo,
    this.mostrarCarrinho = false,
    this.quantidadeCarrinho = 0,
    this.onCarrinhoTap,
    this.mostrarVersao = false,
    this.mostrarVoltar = false,
    this.logoPath = 'assets/images/clubbar_topbar_white.png',
    this.onVoltar,
    this.actions = const [],
  });

  // 🔥 AQUI ESTÁ O SEGREDO
  @override
  Size get preferredSize => const Size.fromHeight(58);

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

  Widget _logoClubbar() {
    if (logoPath == 'assets/images/clubbar_topbar_white.png') {
      return const ClubbarBrandLogo();
    }
    return Image.asset(logoPath, height: 40, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    final bool temTitulo = titulo != null && titulo!.trim().isNotEmpty;

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      centerTitle: true,
      toolbarHeight: 58,
      titleSpacing: temTitulo ? NavigationToolbar.kMiddleSpacing : 10,

      leading: mostrarVoltar
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (onVoltar != null) {
                  onVoltar!();
                  return;
                }

                if (MainNavigationController.telaInterna.value != null) {
                  MainNavigationController.fecharTelaInterna();
                  return;
                }

                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  MainNavigationController.irParaHome();
                }
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
          : Center(child: _logoClubbar()),

      actions: [
        ...actions,
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
                "v1.0.0",
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
