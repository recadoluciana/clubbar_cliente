import 'package:material_ui/material_ui.dart';

import '../screens/login/login_screen.dart';
import '../screens/perfil/perfil_screen.dart';
import '../services/auth_storage.dart';
import '../services/main_navigation_controller.dart';
import 'app_version_text.dart';
import '../core/theme/app_colors.dart';

class ClubbarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? titulo;
  final IconData? iconeTitulo;
  final Color corIconeTitulo;
  final String? imagemTituloAsset;
  final bool mostrarCarrinho;
  final bool carrinhoAntesDaSessao;
  final int quantidadeCarrinho;
  final VoidCallback? onCarrinhoTap;
  final bool mostrarVersao;
  final bool mostrarVoltar;
  final bool mostrarHome;
  final String logoPath;
  final VoidCallback? onVoltar;
  final List<Widget> actions;
  final bool mostrarSessao;
  final bool mostrarPerfil;
  final bool mostrarIconeSessao;
  final bool logoAlinhadaEsquerda;
  final Widget? logoEsquerda;
  final bool mostrarLogo;
  final bool mostrarCorujaNoFinal;
  final bool mostrarLogoPequenaEsquerdaComTitulo;
  final bool tituloAlinhadoEsquerda;

  const ClubbarAppBar({
    super.key,
    this.titulo,
    this.iconeTitulo,
    this.corIconeTitulo = Colors.white,
    this.imagemTituloAsset,
    this.mostrarCarrinho = false,
    this.carrinhoAntesDaSessao = false,
    this.quantidadeCarrinho = 0,
    this.onCarrinhoTap,
    this.mostrarVersao = false,
    this.mostrarVoltar = false,
    this.mostrarHome = false,
    this.logoPath = 'assets/images/clubbar_topbar.png',
    this.onVoltar,
    this.actions = const [],
    this.mostrarSessao = true,
    this.mostrarPerfil = true,
    this.mostrarIconeSessao = true,
    this.logoAlinhadaEsquerda = false,
    this.logoEsquerda,
    this.mostrarLogo = true,
    this.mostrarCorujaNoFinal = false,
    this.mostrarLogoPequenaEsquerdaComTitulo = false,
    this.tituloAlinhadoEsquerda = false,
  });

  const ClubbarAppBar.inicio({Key? key})
    : this(
        key: key,
        logoAlinhadaEsquerda: true,
        logoEsquerda: const Image(
          // Mostra a marca central da arte original, que tem margens pretas.
          image: ExactAssetImage('assets/images/logo1.png', scale: 10),
          width: 124,
          height: 36,
          fit: BoxFit.none,
          semanticLabel: 'Clubbar',
        ),
        mostrarCorujaNoFinal: true,
      );

  // 🔥 AQUI ESTÁ O SEGREDO
  @override
  Size get preferredSize => const Size.fromHeight(58);

  Widget _badgeCarrinho() {
    if (quantidadeCarrinho <= 0) return const SizedBox();

    return Positioned(
      right: 4,
      top: 6,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.marromSuave,
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
      ),
    );
  }

  Widget _logoClubbar({double altura = 40}) {
    return Image.asset(logoPath, height: altura, fit: BoxFit.contain);
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
          if (!mostrarPerfil) return const SizedBox.shrink();
          final nome = ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: mostrarHome && MediaQuery.sizeOf(context).width < 420
                  ? 64
                  : 80,
            ),
            child: Text(
              _primeiroNome(sessao?.nome ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
          void abrirPerfil() {
            MainNavigationController.abrirTela(const PerfilScreen());
          }

          final estilo = TextButton.styleFrom(foregroundColor: Colors.white);
          if (!mostrarIconeSessao) {
            return TextButton(
              onPressed: abrirPerfil,
              style: estilo,
              child: nome,
            );
          }
          return TextButton.icon(
            onPressed: abrirPerfil,
            style: estilo,
            icon: const Icon(
              Icons.person_rounded,
              size: 20,
              color: Colors.amber,
            ),
            label: nome,
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
          label: const Text(
            'Login',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      },
    );
  }

  Widget _acaoCarrinho() => Padding(
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
  );

  @override
  Widget build(BuildContext context) {
    final bool temTitulo = titulo != null && titulo!.trim().isNotEmpty;
    final exibirHome = mostrarHome && !mostrarVoltar;
    final exibirLogoPequenaEsquerda =
        mostrarLogoPequenaEsquerdaComTitulo && temTitulo && !mostrarVoltar;

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      centerTitle: temTitulo
          ? !tituloAlinhadoEsquerda
          : mostrarLogo
          ? !logoAlinhadaEsquerda
          : false,
      toolbarHeight: 58,
      leadingWidth: exibirHome
          ? 100
          : exibirLogoPequenaEsquerda
          ? 118
          : null,
      titleSpacing: temTitulo
          ? (tituloAlinhadoEsquerda ? 8 : NavigationToolbar.kMiddleSpacing)
          : logoAlinhadaEsquerda
          ? 16
          : 10,

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
          : exibirHome
          ? TextButton.icon(
              onPressed: MainNavigationController.irParaHome,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(
                Icons.home_rounded,
                color: Colors.amber,
                size: 22,
              ),
              label: const Text(
                'Home',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            )
          : exibirLogoPequenaEsquerda
          ? Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _logoClubbar(altura: 28),
              ),
            )
          : null,

      title: temTitulo
          ? iconeTitulo == null && imagemTituloAsset == null
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
                    children: [
                      if (imagemTituloAsset != null)
                        Image.asset(
                          imagemTituloAsset!,
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                        )
                      else
                        Icon(iconeTitulo, color: corIconeTitulo, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          titulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  )
          : logoAlinhadaEsquerda
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: logoEsquerda ?? _logoClubbar(),
            )
          : null,

      flexibleSpace: temTitulo || logoAlinhadaEsquerda || !mostrarLogo
          ? null
          : SafeArea(
              bottom: false,
              child: IgnorePointer(
                child: SizedBox(
                  height: 58,
                  child: Padding(
                    // Mantém a logo no centro da tela e reserva espaço para
                    // Home e sessão também em celulares estreitos.
                    padding: EdgeInsets.symmetric(
                      horizontal: exibirHome ? 120 : 0,
                    ),
                    child: Center(child: _logoClubbar()),
                  ),
                ),
              ),
            ),

      actions: [
        ...actions,
        if (mostrarCarrinho && carrinhoAntesDaSessao) _acaoCarrinho(),
        if (mostrarSessao) _botaoSessao(context),
        if (mostrarCarrinho && !carrinhoAntesDaSessao)
          _acaoCarrinho()
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
        if (mostrarCorujaNoFinal)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Image.asset(
              'assets/images/corujao.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
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
