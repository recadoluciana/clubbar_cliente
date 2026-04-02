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
    return AuthResponse(
      accessToken: (json['access_token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'bearer').toString(),
      clienteId: _toInt(json['cliente_id']),
      nmcliente: json['nmcliente']?.toString(),
    );
  }

  static int? _toInt(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    return int.tryParse(valor.toString());
  }
}
