// The payment fields are hosted by Mercado Pago inside the Brick.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class MercadoPagoBrickScreen extends StatefulWidget {
  const MercadoPagoBrickScreen({
    super.key,
    required this.publicKey,
    required this.amount,
  });
  final String publicKey;
  final double amount;
  @override
  State<MercadoPagoBrickScreen> createState() => _MercadoPagoBrickScreenState();
}

class _MercadoPagoBrickScreenState extends State<MercadoPagoBrickScreen> {
  late final html.IFrameElement _frame;
  late final String _viewId;
  StreamSubscription<html.MessageEvent>? _subscription;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'mp-brick-${DateTime.now().microsecondsSinceEpoch}';
    final config = jsonEncode({
      'key': widget.publicKey,
      'amount': widget.amount,
    }).replaceAll('<', r'\u003c');
    _frame = html.IFrameElement()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..srcdoc =
          '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><script src="https://sdk.mercadopago.com/js/v2"></script></head><body><div id="cardPaymentBrick_container"></div><p id="error" role="alert"></p><script>
const cfg = $config;
async function start() { try {
  const mp = new MercadoPago(cfg.key, {locale:'pt-BR'});
  window.brick = await mp.bricks().create('cardPayment', 'cardPaymentBrick_container', {
    initialization: {amount: cfg.amount},
    callbacks: {
      onReady: () => {},
      onError: () => { document.getElementById('error').textContent = 'Não foi possível carregar o formulário. Tente novamente.'; },
      onSubmit: (data) => new Promise((resolve, reject) => {
        if (!data.token || !data.payment_method_id) { reject(); return; }
        parent.postMessage(JSON.stringify({kind:'clubbar-mp-card', data:data}), parent.location.origin);
        resolve();
      })
    }
  });
} catch (e) { document.getElementById('error').textContent = 'Não foi possível carregar o formulário. Confira sua conexão.'; } }
start();
window.addEventListener('pagehide', () => { if (window.brick) window.brick.unmount(); });
</script></body></html>''';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => _frame,
    );
    _subscription = html.window.onMessage.listen((event) {
      if (_submitted ||
          event.origin != html.window.location.origin ||
          event.source != _frame.contentWindow ||
          event.data is! String)
        return;
      try {
        final message = jsonDecode(event.data as String);
        if (message is! Map ||
            message['kind'] != 'clubbar-mp-card' ||
            message['data'] is! Map)
          return;
        final data = Map<String, dynamic>.from(message['data'] as Map);
        if (data['token'] is! String || data['payment_method_id'] is! String)
          return;
        _submitted = true;
        Navigator.of(context).pop(data);
      } catch (_) {
        return;
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagamento com cartão')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: HtmlElementView(viewType: _viewId),
      ),
    ),
  );
}
