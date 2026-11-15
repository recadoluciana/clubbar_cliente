import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../widgets/reserva_tempo_banner.dart';

class MercadoPagoCardData {
  final String token;
  final String paymentMethodId;
  final String? issuerId;
  final int installments;
  final String payerDocument;

  const MercadoPagoCardData({
    required this.token,
    required this.paymentMethodId,
    this.issuerId,
    required this.installments,
    required this.payerDocument,
  });
}

class MercadoPagoCardScreen extends StatefulWidget {
  final String publicKey;
  final String payerEmail;
  final String payerDocument;
  final bool permiteParcelamento;
  final ValueListenable<Duration>? tempoReserva;

  const MercadoPagoCardScreen({
    super.key,
    required this.publicKey,
    required this.payerEmail,
    required this.payerDocument,
    this.permiteParcelamento = false,
    this.tempoReserva,
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
              payerDocument: data['payer_document'].toString(),
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
<style>html,body{margin:0;padding:0;overflow-x:hidden}body{font-family:Arial;padding:18px;box-sizing:border-box;color:#202124}label{display:block;margin-top:12px;font-size:13px}input,select{box-sizing:border-box;width:100%;padding:13px;border:1px solid #bbb;border-radius:8px;margin-top:5px;font-size:16px}button{width:100%;padding:14px;margin-top:20px;border:0;border-radius:8px;background:#1769e0;color:white;font-size:16px}#erro{color:#b3261e;margin-top:12px}</style></head>
<body><h2>Cartão de crédito</h2><form id="form">
<label>Número do cartão<input id="cardNumber" data-checkout="cardNumber" inputmode="numeric" autocomplete="cc-number" maxlength="23" required></label>
<label>Validade<input id="expirationDate" data-checkout="expirationDate" placeholder="MM/AA" inputmode="numeric" autocomplete="cc-exp" maxlength="5" required></label>
<label>Código de segurança<input id="securityCode" data-checkout="securityCode" inputmode="numeric" autocomplete="cc-csc" maxlength="4" required></label>
<label>Nome no cartão<input id="cardholderName" data-checkout="cardholderName" required></label>
<label>CPF do titular do cartão<input id="identificationNumber" data-checkout="identificationNumber" inputmode="numeric" maxlength="14" required></label>
${widget.permiteParcelamento ? '<label>Parcelas<select id="installments" data-checkout="installments"><option value="1">1x</option><option value="2">2x</option><option value="3">3x</option><option value="6">6x</option><option value="12">12x</option></select></label>' : '<input type="hidden" id="installments" value="1">'}
<input type="hidden" id="cardholderEmail" data-checkout="cardholderEmail" value="${widget.payerEmail}">
<button type="submit">Pagar com cartão</button><div id="erro"></div></form>
<script>const mp=new MercadoPago('${widget.publicKey}',{locale:'pt-BR'});const form=document.getElementById('form');document.querySelectorAll('input,select').forEach(el=>el.addEventListener('focus',()=>setTimeout(()=>el.scrollIntoView({block:'nearest',inline:'nearest'}),350)));cardNumber.addEventListener('input',()=>{cardNumber.value=cardNumber.value.replace(/\\D/g,'').slice(0,19).replace(/(.{4})/g,'\$1 ').trim()});expirationDate.addEventListener('input',()=>{const v=expirationDate.value.replace(/\\D/g,'').slice(0,4);expirationDate.value=v.length>2?v.slice(0,2)+'/'+v.slice(2):v});identificationNumber.addEventListener('input',()=>{let v=identificationNumber.value.replace(/\\D/g,'').slice(0,11);v=v.replace(/^(\\d{3})(\\d)/,'\$1.\$2').replace(/^(\\d{3})\\.(\\d{3})(\\d)/,'\$1.\$2.\$3').replace(/(\\d{3})(\\d{1,2})\$/,'\$1-\$2');identificationNumber.value=v});securityCode.addEventListener('input',()=>{securityCode.value=securityCode.value.replace(/\\D/g,'').slice(0,4)});form.addEventListener('submit',async e=>{e.preventDefault();document.querySelector('button').disabled=true;let etapa='dados';try{const numero=cardNumber.value.replace(/\\D/g,'');const validade=expirationDate.value.split('/');if(numero.length<13||validade.length!==2||validade[1].length!==2||Number(validade[0])<1||Number(validade[0])>12){throw new Error('Confira o número e a validade do cartão (MM/AA).')}etapa='tokenizacao';const r=await mp.createCardToken({cardNumber:numero,cardholderName:cardholderName.value.trim(),cardExpirationMonth:validade[0],cardExpirationYear:'20'+validade[1],securityCode:securityCode.value,identificationType:'CPF',identificationNumber:identificationNumber.value.replace(/\\D/g,'')});etapa='bandeira';const pm=await mp.getPaymentMethods({bin:numero.slice(0,6)});if(!r.id||!pm.results||!pm.results.length)throw new Error('Não foi possível identificar o cartão. Confira os dados e tente novamente.');ClubbarCard.postMessage(JSON.stringify({token:r.id,payment_method_id:pm.results[0].id,issuer_id:pm.results[0].issuer&&pm.results[0].issuer.id,installments:installments.value,payer_document:identificationNumber.value.replace(/\\D/g,'')}));}catch(x){document.getElementById('erro').textContent=etapa==='dados'?'Confira o número e a validade do cartão (MM/AA).':etapa==='tokenizacao'?'Não foi possível validar o cartão no Mercado Pago (etapa: tokenização). Confira os dados ou tente novamente.':'Não foi possível identificar a bandeira do cartão no Mercado Pago. Tente novamente.';document.querySelector('button').disabled=false;}});</script></body></html>''';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagamento com cartão')),
    body: Column(
      children: [
        if (widget.tempoReserva != null)
          ReservaTempoBanner(tempo: widget.tempoReserva!),
        Expanded(child: WebViewWidget(controller: _controller)),
      ],
    ),
  );
}
