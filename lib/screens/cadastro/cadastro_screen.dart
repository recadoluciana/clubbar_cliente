import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class CadastroClienteScreen extends StatefulWidget {
  const CadastroClienteScreen({super.key});

  @override
  State<CadastroClienteScreen> createState() => _CadastroClienteScreenState();
}

class _CadastroClienteScreenState extends State<CadastroClienteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();

  final apiService = ApiService();

  bool _carregando = false;
  bool _obscureSenha = true;
  bool _obscureConfirmarSenha = true;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    _telefoneCtrl.dispose();
    _cpfCtrl.dispose();
    super.dispose();
  }

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _validarEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email.trim());
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

      int resto = soma % 11;
      return resto < 2 ? 0 : 11 - resto;
    }

    final base9 = cpf.substring(0, 9);
    final dig1 = calcularDigito(base9, 10);

    final base10 = cpf.substring(0, 9) + dig1.toString();
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
    return '${numeros.substring(0, 3)}.${numeros.substring(3, 6)}.${numeros.substring(6, 9)}-${numeros.substring(9, numeros.length > 11 ? 11 : numeros.length)}';
  }

  String _formatarTelefone(String valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.length <= 2) return numeros;
    if (numeros.length <= 7) {
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2)}';
    }
    if (numeros.length <= 11) {
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2, numeros.length == 10 ? 6 : 7)}-${numeros.substring(numeros.length == 10 ? 6 : 7)}';
    }

    final cortado = numeros.substring(0, 11);
    return '(${cortado.substring(0, 2)}) ${cortado.substring(2, 7)}-${cortado.substring(7)}';
  }

  Future<void> _cadastrar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
    });

    try {
      await apiService.cadastrarCliente(
        nome: _nomeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        senha: _senhaCtrl.text,
        telefone: _somenteNumeros(_telefoneCtrl.text),
        cpf: _somenteNumeros(_cpfCtrl.text),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro realizado com sucesso')),
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
          _carregando = false;
        });
      }
    }
  }

  InputDecoration _decoracao({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(title: const Text('Novo por aqui?')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Crie sua conta',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Preencha seus dados para continuar no Clubbar.',
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
                keyboardType: TextInputType.emailAddress,
                decoration: _decoracao(
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Informe seu e-mail';
                  if (!_validarEmail(v)) return 'E-mail inválido';
                  return null;
                },
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
              const SizedBox(height: 14),

              TextFormField(
                controller: _senhaCtrl,
                obscureText: _obscureSenha,
                decoration: _decoracao(label: 'Senha', icon: Icons.lock_outline)
                    .copyWith(
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureSenha = !_obscureSenha;
                          });
                        },
                        icon: Icon(
                          _obscureSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                validator: (value) {
                  final v = value ?? '';
                  if (v.isEmpty) return 'Informe uma senha';
                  if (v.length < 6) {
                    return 'A senha deve ter pelo menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _confirmarSenhaCtrl,
                obscureText: _obscureConfirmarSenha,
                decoration:
                    _decoracao(
                      label: 'Confirmar senha',
                      icon: Icons.lock_reset_outlined,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureConfirmarSenha = !_obscureConfirmarSenha;
                          });
                        },
                        icon: Icon(
                          _obscureConfirmarSenha
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                validator: (value) {
                  final v = value ?? '';
                  if (v.isEmpty) return 'Confirme sua senha';
                  if (v != _senhaCtrl.text) return 'As senhas não conferem';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _carregando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Criar conta',
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
      ),
    );
  }
}
