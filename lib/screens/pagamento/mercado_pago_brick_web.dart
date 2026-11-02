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
let submitWatchdog;
document.addEventListener('click', (event) => {
  const button = event.target.closest && event.target.closest('button');
  if (!button || !button.textContent.includes('Pagar')) return;
  clearTimeout(submitWatchdog);
  console.info('Mercado Pago Brick: pagamento solicitado');
  submitWatchdog = setTimeout(() => {
    document.getElementById('error').textContent = 'O Mercado Pago não concluiu a validação. Confira os campos e aguarde antes de tentar novamente.';
    console.warn('Mercado Pago Brick: envio não chegou ao aplicativo');
  }, 15000);
}, true);
async function start() { try {
  const mp = new MercadoPago(cfg.key, {locale:'pt-BR'});
  window.brick = await mp.bricks().create('cardPayment', 'cardPaymentBrick_container', {
    initialization: {amount: cfg.amount},
    callbacks: {
      onReady: () => {},
      onError: (error) => {
        clearTimeout(submitWatchdog);
        const type = error && typeof error.type === 'string' && /^[a-zA-Z0-9_-]+\$/.test(error.type) ? error.type : 'desconhecido';
        console.warn('Mercado Pago Brick: falha ao processar o formulário', type);
        if (!document.getElementById('error').textContent) document.getElementById('error').textContent = 'Não foi possível validar o cartão. Confira os dados e tente novamente.';
      },
      onSubmit: (data) => new Promise((resolve, reject) => {
        clearTimeout(submitWatchdog);
        const form = data && (data.formData || data);
        console.info('Mercado Pago Brick: dados recebidos', {token: !!(form && form.token), metodo: !!(form && form.payment_method_id)});
        if (!form || !form.token || !form.payment_method_id) {
          document.getElementById('error').textContent = 'Não foi possível obter os dados tokenizados do cartão. Confira os dados e tente novamente.';
          reject(new Error('Dados tokenizados incompletos'));
          return;
        }
        document.getElementById('error').textContent = 'Enviando pagamento. Aguarde...';
        let timer;
        const acknowledge = (event) => {
          if (event.source !== parent || event.origin !== parent.location.origin || event.data !== 'clubbar-mp-card-received') return;
          clearTimeout(timer);
          window.removeEventListener('message', acknowledge);
          resolve();
        };
        window.addEventListener('message', acknowledge);
        timer = setTimeout(() => {
          window.removeEventListener('message', acknowledge);
          document.getElementById('error').textContent = 'Não foi possível enviar o cartão ao aplicativo. Atualize a página e tente novamente.';
          reject(new Error('Aplicativo não confirmou o recebimento'));
        }, 8000);
        parent.postMessage(JSON.stringify({kind:'clubbar-mp-card', data:form}), parent.location.origin);
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
      if (event.data is String &&
          (event.data as String).contains('clubbar-mp-card') &&
          (event.origin != html.window.location.origin ||
              event.source != _frame.contentWindow)) {
        debugPrint('Mercado Pago Brick: mensagem recusada por origem ou janela');
      }
      if (_submitted ||
          !mounted ||
          event.origin != html.window.location.origin ||
          event.source != _frame.contentWindow ||
          event.data is! String) {
        return;
      }
      try {
        final message = jsonDecode(event.data as String);
        if (message is! Map ||
            message['kind'] != 'clubbar-mp-card' ||
            message['data'] is! Map) {
          return;
        }
        final data = Map<String, dynamic>.from(message['data'] as Map);
        if (data['token'] is! String || data['payment_method_id'] is! String) {
          debugPrint('Mercado Pago Brick: mensagem com dados incompletos');
          return;
        }
        debugPrint('Mercado Pago Brick: dados tokenizados recebidos pelo Client');
        _submitted = true;
        _frame.contentWindow?.postMessage(
          'clubbar-mp-card-received',
          html.window.location.origin,
        );
        Navigator.of(context).pop(data);
      } catch (_) {
        debugPrint('Mercado Pago Brick: falha ao processar mensagem do formulário');
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
