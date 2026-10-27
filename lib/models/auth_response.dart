class AuthResponse {
  final String accessToken;
  final String tokenType;
  final int? clienteId;
  final String? nmcliente;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    this.clienteId,
    this.nmcliente,
  });

  factory AuthResponse.fromJson(dynamic dados) {
    if (dados is! Map) {
      throw const FormatException('Resposta de autenticação inválida.');
    }

    final json = Map<String, dynamic>.from(dados);
    final clienteBruto = json['cliente'];
    final cliente = clienteBruto is Map
        ? Map<String, dynamic>.from(clienteBruto)
        : <String, dynamic>{};

    final accessToken = (json['access_token'] ?? '').toString().trim();
    final clienteId = _toInt(json['cliente_id'] ?? cliente['cliente_id']);
    if (accessToken.isEmpty || clienteId == null || clienteId <= 0) {
      throw const FormatException('Resposta de autenticação incompleta.');
    }

    return AuthResponse(
      accessToken: accessToken,
      tokenType: (json['token_type'] ?? 'bearer').toString(),
      clienteId: clienteId,
      nmcliente: (json['nmcliente'] ?? cliente['nmcliente'])?.toString(),
    );
  }

  static int? _toInt(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    return int.tryParse(valor.toString());
  }
}
