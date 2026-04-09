import 'dart:js_interop';
import 'dart:js_util' as js_util;

@JS('pagbankEncryptCard')
external JSAny? _pagbankEncryptCard(JSAny payload);

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
    final payload = js_util.jsify({
      'publicKey': publicKey,
      'holder': holder,
      'number': number,
      'expMonth': expMonth,
      'expYear': expYear,
      'securityCode': securityCode,
    });

    final result = _pagbankEncryptCard(payload);

    if (result == null) {
      throw Exception('SDK do PagBank não carregado');
    }

    final encryptedCard = (js_util.getProperty(result, 'encryptedCard') ?? '')
        .toString();

    final hasErrors =
        (js_util.getProperty(result, 'hasErrors') ?? false) == true;

    final rawErrors = js_util.getProperty(result, 'errors');
    final errors = <String>[];

    if (rawErrors != null) {
      final rawList = js_util.dartify(rawErrors);
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map && item['message'] != null) {
            errors.add(item['message'].toString());
          } else {
            errors.add(item.toString());
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
