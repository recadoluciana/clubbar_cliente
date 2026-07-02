import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../widgets/clubbar_app_bar.dart';

class AsaasCheckoutScreen extends StatefulWidget {
  final String url;

  const AsaasCheckoutScreen({super.key, required this.url});

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

            if (url.contains('/asaas/retorno')) {
              Navigator.of(context).pop(true);
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
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_carregando) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
