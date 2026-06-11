import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../widgets/clubbar_app_bar.dart';

class CheckoutCartaoScreen extends StatefulWidget {
  final String url;

  const CheckoutCartaoScreen({super.key, required this.url});

  @override
  State<CheckoutCartaoScreen> createState() => _CheckoutCartaoScreenState();
}

class _CheckoutCartaoScreenState extends State<CheckoutCartaoScreen> {
  WebViewController? controller;
  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    _carregarCheckout();
  }

  Future<void> _carregarCheckout() async {
    try {
      final uri = Uri.parse(widget.url);

      final webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() => carregando = true);
              }
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() => carregando = false);
              }
            },
            onNavigationRequest: (request) {
              final url = request.url;

              if (url.startsWith('clubbar://pagamento-sucesso')) {
                Navigator.pop(context, true);
                return NavigationDecision.prevent;
              }

              if (url.startsWith('clubbar://pagamento-cancelado')) {
                Navigator.pop(context, false);
                return NavigationDecision.prevent;
              }

              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(uri);

      if (!mounted) return;

      setState(() {
        controller = webController;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '');
        carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            )
          : Stack(
              children: [
                if (controller != null) WebViewWidget(controller: controller!),
                if (carregando)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
