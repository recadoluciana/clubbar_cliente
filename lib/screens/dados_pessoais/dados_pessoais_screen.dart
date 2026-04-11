import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class DadosPessoaisScreen extends StatefulWidget {
  const DadosPessoaisScreen({super.key});

  @override
  State<DadosPessoaisScreen> createState() => _DadosPessoaisScreenState();
}

class _DadosPessoaisScreenState extends State<DadosPessoaisScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();

  final apiService = ApiService();

  bool carregando = true;
  bool salvando = false;
  String? erro;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _cpfCtrl.dispose();
    super.dispose();
  }

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _validarCPF(String cpf) {
    cpf = _somenteNumeros(cpf);

    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    int calcularDigito(String base, int pesoInicial) {
      int soma = 0;
      int peso = pesoInicial;

      for (int i = 0; i < base.length; i++) {
        soma += int.parse(base[i]) * peso;
        peso--;
      }

      final resto = soma % 11;
      return resto < 2 ? 0 : 11 - resto;
    }

    final base9 = cpf.substring(0, 9);
    final dig1 = calcularDigito(base9, 10);
    final base10 = '$base9$dig1';
    final dig2 = calcularDigito(base10, 11);

    return cpf == '$base9$dig1$dig2';
  }

  String _formatarCPF(String valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.length <= 3) return numeros;
    if (numeros.length <= 6) {
      return '${numeros.substring(0, 3)}.${numeros.substring(3)}';
    }
    if (numeros.length <= 9) {
      return '${numeros.substring(0, 3)}.${numeros.substring(3, 6)}.${numeros.substring(6)}';
    }

    final n = numeros.length > 11 ? numeros.substring(0, 11) : numeros;
    return '${n.substring(0, 3)}.${n.substring(3, 6)}.${n.substring(6, 9)}-${n.substring(9)}';
  }

  String _formatarTelefone(String valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.length <= 2) return numeros;
    if (numeros.length <= 6) {
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2)}';
    }

    final n = numeros.length > 11 ? numeros.substring(0, 11) : numeros;

    if (n.length <= 10) {
      return '(${n.substring(0, 2)}) ${n.substring(2, 6)}-${n.substring(6)}';
    }

    return '(${n.substring(0, 2)}) ${n.substring(2, 7)}-${n.substring(7)}';
  }

  Future<void> carregarDados() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final data = await apiService.buscarMeuPerfil();

      _nomeCtrl.text = (data['nmcliente'] ?? '').toString();
      _emailCtrl.text = (data['emailcliente'] ?? '').toString();
      _telefoneCtrl.text = (data['nrtelcliente'] ?? '').toString();
      _cpfCtrl.text = (data['nrcpfcliente'] ?? '').toString();
    } catch (e) {
      erro = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> salvar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      salvando = true;
    });

    try {
      await apiService.atualizarMeuPerfil(
        nome: _nomeCtrl.text.trim(),
        telefone: _somenteNumeros(_telefoneCtrl.text),
        cpf: _somenteNumeros(_cpfCtrl.text),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados atualizados com sucesso')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  InputDecoration _decoracao({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(title: const Text('Dados pessoais')),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(erro!, textAlign: TextAlign.center),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Seus dados',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Atualize suas informações pessoais.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nomeCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoracao(
                      label: 'Nome completo',
                      icon: Icons.person_outline,
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Informe seu nome';
                      if (v.length < 3) return 'Nome muito curto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _emailCtrl,
                    readOnly: true,
                    enabled: false,
                    decoration: _decoracao(
                      label: 'E-mail',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'O e-mail de acesso não pode ser alterado nesta tela.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _telefoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _decoracao(
                      label: 'Celular',
                      icon: Icons.phone_outlined,
                    ),
                    onChanged: (value) {
                      final formatado = _formatarTelefone(value);
                      if (formatado != value) {
                        _telefoneCtrl.value = TextEditingValue(
                          text: formatado,
                          selection: TextSelection.collapsed(
                            offset: formatado.length,
                          ),
                        );
                      }
                    },
                    validator: (value) {
                      final numeros = _somenteNumeros(value ?? '');
                      if (numeros.isEmpty) return null;
                      if (numeros.length < 10 || numeros.length > 11) {
                        return 'Telefone inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _cpfCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _decoracao(
                      label: 'CPF',
                      icon: Icons.badge_outlined,
                    ),
                    onChanged: (value) {
                      final formatado = _formatarCPF(value);
                      if (formatado != value) {
                        _cpfCtrl.value = TextEditingValue(
                          text: formatado,
                          selection: TextSelection.collapsed(
                            offset: formatado.length,
                          ),
                        );
                      }
                    },
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return null;
                      if (!_validarCPF(v)) return 'CPF inválido';
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: salvando ? null : salvar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: salvando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Salvar alterações',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
