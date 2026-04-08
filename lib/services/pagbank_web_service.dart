import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('pagbankEncryptCard')
external JSAny? _pagbankEncryptCard(JSAny payload);

extension _MapToJs on Map<String, dynamic> {
  JSAny toJsObject() {
    final jsObject = web.Object();
    forEach((key, value) {
      web.js_util.setProperty(jsObject, key, value);
    });
    return jsObject;
  }
}

class PagBankEncryptResult {
  final String encryptedCard;
  final bool hasErrors;
  final List<String> errors;

  PagBankEncryptResult({
    required this.encryptedCard,
    required this.hasErrors,
    required this.errors,
  });
}

class PagBankWebService {
  static PagBankEncryptResult encryptCard({
    required String publicKey,
    required String holder,
    required String number,
    required String expMonth,
    required String expYear,
    required String securityCode,
  }) {
    final payload = {
      'publicKey': publicKey,
      'holder': holder,
      'number': number,
      'expMonth': expMonth,
      'expYear': expYear,
      'securityCode': securityCode,
    };

    final result = _pagbankEncryptCard(payload.toJsObject());

    if (result == null) {
      throw Exception('SDK do PagBank não carregado');
    }

    final encryptedCard =
        (web.js_util.getProperty(result, 'encryptedCard') ?? '').toString();

    final hasErrors =
        (web.js_util.getProperty(result, 'hasErrors') ?? false) == true;

    final rawErrors = web.js_util.getProperty(result, 'errors');
    final errors = <String>[];

    if (rawErrors != null) {
      final length = (web.js_util.getProperty(rawErrors, 'length') ?? 0) as int;
      for (var i = 0; i < length; i++) {
        final item = web.js_util.callMethod(rawErrors, 'at', [i]);
        if (item != null) {
          final message = web.js_util.getProperty(item, 'message');
          if (message != null) {
            errors.add(message.toString());
          }
        }
      }
    }

    return PagBankEncryptResult(
      encryptedCard: encryptedCard,
      hasErrors: hasErrors,
      errors: errors,
    );
  }
}
