import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MercadoPagoCardData {
  final String token;
  final String paymentMethodId;
  final String? issuerId;
  final int installments;

  const MercadoPagoCardData({
    required this.token,
    required this.paymentMethodId,
    this.issuerId,
    required this.installments,
  });
}

class MercadoPagoCardScreen extends StatefulWidget {
  final String publicKey;
  final String payerEmail;
  final String payerDocument;

  const MercadoPagoCardScreen({
    super.key,
    required this.publicKey,
    required this.payerEmail,
    required this.payerDocument,
  });

  @override
  State<MercadoPagoCardScreen> createState() => _MercadoPagoCardScreenState();
}

class _MercadoPagoCardScreenState extends State<MercadoPagoCardScreen> {
  late final WebViewController _controller;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ClubbarCard',
        onMessageReceived: (message) {
          if (_enviando) return;
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          if (data['error'] != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(data['error'].toString())));
            return;
          }
          _enviando = true;
          Navigator.pop(
            context,
            MercadoPagoCardData(
              token: data['token'].toString(),
              paymentMethodId: data['payment_method_id'].toString(),
              issuerId: data['issuer_id']?.toString(),
              installments: int.tryParse(data['installments'].toString()) ?? 1,
            ),
          );
        },
      )
      ..loadHtmlString(_html);
  }

  String get _html =>
      '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://sdk.mercadopago.com/js/v2"></script>
<style>body{font-family:Arial;margin:18px;color:#202124}label{display:block;margin-top:12px;font-size:13px}input,select{box-sizing:border-box;width:100%;padding:13px;border:1px solid #bbb;border-radius:8px;margin-top:5px;font-size:16px}button{width:100%;padding:14px;margin-top:20px;border:0;border-radius:8px;background:#1769e0;color:white;font-size:16px}#erro{color:#b3261e;margin-top:12px}</style></head>
<body><h2>Cartão de crédito</h2><form id="form">
<label>Número do cartão<input id="cardNumber" data-checkout="cardNumber" inputmode="numeric" required></label>
<label>Validade<input id="expirationDate" data-checkout="expirationDate" placeholder="MM/AA" required></label>
<label>Código de segurança<input id="securityCode" data-checkout="securityCode" inputmode="numeric" required></label>
<label>Nome no cartão<input id="cardholderName" data-checkout="cardholderName" required></label>
<label>Parcelas<select id="installments" data-checkout="installments"><option value="1">1x</option><option value="2">2x</option><option value="3">3x</option><option value="6">6x</option><option value="12">12x</option></select></label>
<input type="hidden" id="cardholderEmail" data-checkout="cardholderEmail" value="${widget.payerEmail}">
<input type="hidden" id="identificationNumber" data-checkout="identificationNumber" value="${widget.payerDocument}">
<button type="submit">Pagar com cartão</button><div id="erro"></div></form>
<script>const mp=new MercadoPago('${widget.publicKey}',{locale:'pt-BR'});const form=document.getElementById('form');form.addEventListener('submit',async e=>{e.preventDefault();document.querySelector('button').disabled=true;try{const r=await mp.createCardToken({cardNumber:cardNumber.value,cardholderName:cardholderName.value,cardExpirationMonth:expirationDate.value.split('/')[0],cardExpirationYear:'20'+expirationDate.value.split('/')[1],securityCode:securityCode.value,identificationType:'CPF',identificationNumber:identificationNumber.value});const pm=await mp.getPaymentMethods({bin:cardNumber.value.replace(/\\D/g,'').slice(0,6)});ClubbarCard.postMessage(JSON.stringify({token:r.id,payment_method_id:pm.results[0].id,issuer_id:pm.results[0].issuer&&pm.results[0].issuer.id,installments:installments.value}));}catch(x){document.getElementById('erro').textContent=x.message||'Confira os dados do cartão.';document.querySelector('button').disabled=false;}});</script></body></html>''';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagamento com cartão')),
    body: WebViewWidget(controller: _controller),
  );
}
