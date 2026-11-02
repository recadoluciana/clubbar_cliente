import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/reserva_tempo_banner.dart';

class AsaasCheckoutScreen extends StatefulWidget {
  final String url;
  final ValueListenable<Duration>? tempoReserva;

  const AsaasCheckoutScreen({super.key, required this.url, this.tempoReserva});

  @override
  State<AsaasCheckoutScreen> createState() => _AsaasCheckoutScreenState();
}

class _AsaasCheckoutScreenState extends State<AsaasCheckoutScreen> {
  late final WebViewController _controller;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _carregando = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _carregando = false);
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;

            if (url.contains('/asaas/retorno') ||
                url.contains('/mercado-pago/retorno')) {
              final uri = Uri.parse(url);
              final acao = uri.queryParameters['acao'];

              if (acao == 'cancelado' || acao == 'expirado') {
                Navigator.pop(context, false);
              } else {
                Navigator.pop(context, true);
              }

              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClubbarAppBar(
        titulo: 'Pagamento com cartão',
        mostrarVoltar: true,
        mostrarSessao: false,
      ),
      body: Column(
        children: [
          if (widget.tempoReserva != null)
            ReservaTempoBanner(tempo: widget.tempoReserva!),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_carregando)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
