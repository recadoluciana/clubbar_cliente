import 'package:flutter/material.dart';
import '../screens/login/login_screen.dart';
import '../screens/perfil/perfil_screen.dart';
import '../services/auth_storage.dart';
import '../services/main_navigation_controller.dart';
import 'app_version_text.dart';

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
  final bool mostrarSessao;

  const ClubbarAppBar({
    super.key,
    this.titulo,
    this.mostrarCarrinho = false,
    this.quantidadeCarrinho = 0,
    this.onCarrinhoTap,
    this.mostrarVersao = false,
    this.mostrarVoltar = false,
    this.logoPath = 'assets/images/clubbar_topbar.png',
    this.onVoltar,
    this.actions = const [],
    this.mostrarSessao = true,
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
    return Image.asset(logoPath, height: 40, fit: BoxFit.contain);
  }

  Future<_SessaoAppBar> _carregarSessao() async {
    final armazenamento = AuthStorage();
    return _SessaoAppBar(
      logado: await armazenamento.estaLogado(),
      nome: await armazenamento.obterNmcliente() ?? '',
    );
  }

  String _primeiroNome(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return 'Perfil';
    final primeiro = partes.first.toLowerCase();
    return '${primeiro[0].toUpperCase()}${primeiro.substring(1)}';
  }

  Widget _botaoSessao(BuildContext context) {
    return FutureBuilder<_SessaoAppBar>(
      future: _carregarSessao(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(width: 8);
        }
        final sessao = snapshot.data;
        if (sessao?.logado == true) {
          return TextButton.icon(
            onPressed: () {
              MainNavigationController.abrirTela(const PerfilScreen());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(
              Icons.person_rounded,
              size: 20,
              color: Colors.amber,
            ),
            label: Text(
              _primeiroNome(sessao?.nome ?? ''),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        }
        return TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(mostrarVoltar: true),
            ),
          ),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.login_rounded, size: 21),
          label: const Text('Login', style: TextStyle(fontWeight: FontWeight.w800)),
        );
      },
    );
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

                // Rotas temporárias (diálogos de fluxo, compra e pagamento)
                // devem ser fechadas antes das telas internas da navegação.
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                  return;
                }

                if (MainNavigationController.telaInterna.value != null) {
                  MainNavigationController.fecharTelaInterna();
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
          : null,

      flexibleSpace: temTitulo
          ? null
          : SafeArea(
              bottom: false,
              child: IgnorePointer(
                child: SizedBox(
                  height: 58,
                  child: Center(child: _logoClubbar()),
                ),
              ),
            ),

      actions: [
        ...actions,
        if (mostrarSessao) _botaoSessao(context),
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
              child: AppVersionText(
                prefix: 'v',
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

class _SessaoAppBar {
  final bool logado;
  final String nome;

  const _SessaoAppBar({required this.logado, required this.nome});
}
