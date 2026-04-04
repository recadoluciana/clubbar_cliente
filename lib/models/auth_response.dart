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

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final cliente = json['cliente'] as Map<String, dynamic>?;

    return AuthResponse(
      accessToken: (json['access_token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'bearer').toString(),
      clienteId: _toInt(json['cliente_id'] ?? cliente?['cliente_id']),
      nmcliente: (json['nmcliente'] ?? cliente?['nmcliente'])?.toString(),
    );
  }

  static int? _toInt(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    return int.tryParse(valor.toString());
  }
}
