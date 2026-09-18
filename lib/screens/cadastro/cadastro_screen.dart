import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../widgets/clubbar_page_header.dart';
import '../../services/cep_service.dart';

class CadastroClienteScreen extends StatefulWidget {
  const CadastroClienteScreen({super.key});

  @override
  State<CadastroClienteScreen> createState() => _CadastroClienteScreenState();
}

class _CadastroClienteScreenState extends State<CadastroClienteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _confirmarEmailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();

  final apiService = ApiService();
  final _cepService = CepService();

  bool _carregando = false;
  bool _obscureSenha = true;
  bool _obscureConfirmarSenha = true;
  bool _consultandoCep = false;
  String? _ultimoCepConsultado;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _confirmarEmailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    _telefoneCtrl.dispose();
    _cpfCtrl.dispose();
    _cepCtrl.dispose();
    _enderecoCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _ufCtrl.dispose();
    super.dispose();
  }

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _validarEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
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

  String _formatarCEP(String valor) {
    final numeros = _somenteNumeros(valor);
    if (numeros.length <= 5) return numeros;
    final n = numeros.length > 8 ? numeros.substring(0, 8) : numeros;
    return '${n.substring(0, 5)}-${n.substring(5)}';
  }

  Future<void> _buscarCep() async {
    final cep = _somenteNumeros(_cepCtrl.text);
    if (cep.length != 8 || _consultandoCep || cep == _ultimoCepConsultado) {
      return;
    }
    setState(() => _consultandoCep = true);
    try {
      final endereco = await _cepService.buscar(cep);
      if (!mounted) return;
      setState(() {
        _ultimoCepConsultado = cep;
        _cepCtrl.text = _formatarCEP(endereco.cep);
        _enderecoCtrl.text = endereco.logradouro;
        _bairroCtrl.text = endereco.bairro;
        _cidadeCtrl.text = endereco.cidade;
        _ufCtrl.text = endereco.uf;
      });
      FocusScope.of(context).nextFocus();
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _consultandoCep = false);
    }
  }

  String? sugerirEmail(String email) {
    final original = email.trim();
    final e = original.toLowerCase();

    if (e.endsWith('.con')) {
      return '${original.substring(0, original.length - 4)}.com';
    }

    if (e.endsWith('.ccom')) {
      return '${original.substring(0, original.length - 5)}.com';
    }

    if (e.endsWith('.comm')) {
      return '${original.substring(0, original.length - 5)}.com';
    }

    if (e.contains('@gmai.com')) {
      return original.replaceAll(
        RegExp(r'@gmai\.com$', caseSensitive: false),
        '@gmail.com',
      );
    }

    if (e.contains('@gmil.com')) {
      return original.replaceAll(
        RegExp(r'@gmil\.com$', caseSensitive: false),
        '@gmail.com',
      );
    }

    if (e.contains('@hotmial.com')) {
      return original.replaceAll(
        RegExp(r'@hotmial\.com$', caseSensitive: false),
        '@hotmail.com',
      );
    }

    if (e.contains('@hotmai.com')) {
      return original.replaceAll(
        RegExp(r'@hotmai\.com$', caseSensitive: false),
        '@hotmail.com',
      );
    }

    if (e.contains('@outlok.com')) {
      return original.replaceAll(
        RegExp(r'@outlok\.com$', caseSensitive: false),
        '@outlook.com',
      );
    }

    if (e.contains('@outllok.com')) {
      return original.replaceAll(
        RegExp(r'@outllok\.com$', caseSensitive: false),
        '@outlook.com',
      );
    }

    return null;
  }

  Future<void> _cadastrar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    String email = _emailCtrl.text.trim();

    final sugestao = sugerirEmail(email);

    if (sugestao != null && sugestao.toLowerCase() != email.toLowerCase()) {
      final usarSugestao = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirmar e-mail'),
          content: Text('Você quis dizer:\n\n$sugestao'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Não'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sim'),
            ),
          ],
        ),
      );

      if (usarSugestao == true) {
        email = sugestao;
        _emailCtrl.text = sugestao;
        _confirmarEmailCtrl.text = sugestao;
      } else {
        return;
      }
    }

    setState(() {
      _carregando = true;
    });

    try {
      await apiService.cadastrarCliente(
        nome: _nomeCtrl.text.trim(),
        email: email,
        senha: _senhaCtrl.text,
        telefone: _somenteNumeros(_telefoneCtrl.text),
        cpf: _somenteNumeros(_cpfCtrl.text),
        endereco: _enderecoCtrl.text.trim(),
        numero: _numeroCtrl.text.trim(),
        complemento: _complementoCtrl.text.trim(),
        bairro: _bairroCtrl.text.trim(),
        cep: _somenteNumeros(_cepCtrl.text),
        cidade: _cidadeCtrl.text.trim(),
        uf: _ufCtrl.text.trim().toUpperCase(),
      );

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Cadastro realizado com sucesso.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, apiService.mensagemErroAmigavel(e));
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            const ClubbarPageHeader(
              titulo: 'Crie sua conta',
              subtitulo: 'Informe seus dados pessoais',
              icone: Icons.person_add_alt_1_rounded,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'O CPF e o endereço completo são necessários para realizar compras via PIX e cartão de crédito. Essas informações serão solicitadas somente neste cadastro e reutilizadas com segurança nas suas compras.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nomeCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoracao(
                        label: 'Nome',
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
                      controller: _confirmarEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoracao(
                        label: 'Confirmar e-mail',
                        icon: Icons.mark_email_read_outlined,
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';

                        if (v.isEmpty) return 'Confirme seu e-mail';
                        if (!_validarEmail(v)) return 'E-mail inválido';

                        if (v.toLowerCase() !=
                            _emailCtrl.text.trim().toLowerCase()) {
                          return 'Os e-mails não conferem';
                        }

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

                        if (v.isEmpty) return 'Informe seu CPF';
                        if (!_validarCPF(v)) return 'CPF inválido';

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _cepCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          _decoracao(
                            label: 'CEP',
                            icon: Icons.pin_drop_outlined,
                          ).copyWith(
                            suffixIcon: _consultandoCep
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    onPressed: _buscarCep,
                                    icon: const Icon(Icons.search_rounded),
                                  ),
                          ),
                      onChanged: (value) {
                        final formatado = _formatarCEP(value);
                        if (formatado != value) {
                          _cepCtrl.value = TextEditingValue(
                            text: formatado,
                            selection: TextSelection.collapsed(
                              offset: formatado.length,
                            ),
                          );
                        }
                        final numeros = _somenteNumeros(formatado);
                        if (numeros.length == 8) _buscarCep();
                      },
                      onFieldSubmitted: (_) => _buscarCep(),
                      validator: (value) =>
                          _somenteNumeros(value ?? '').length == 8
                          ? null
                          : 'Informe um CEP válido',
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _enderecoCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoracao(
                        label: 'Endereço',
                        icon: Icons.route_outlined,
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Informe seu endereço'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _numeroCtrl,
                            keyboardType: TextInputType.streetAddress,
                            decoration: _decoracao(
                              label: 'Número',
                              icon: Icons.numbers_rounded,
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Informe o número'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _complementoCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: _decoracao(
                              label: 'Complemento',
                              icon: Icons.apartment_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _bairroCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoracao(
                        label: 'Bairro',
                        icon: Icons.location_city_outlined,
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Informe seu bairro'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _cidadeCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: _decoracao(
                              label: 'Cidade',
                              icon: Icons.location_on_outlined,
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Informe sua cidade'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _ufCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 2,
                            decoration: _decoracao(
                              label: 'UF',
                              icon: Icons.map_outlined,
                            ).copyWith(counterText: ''),
                            validator: (value) => value?.trim().length == 2
                                ? null
                                : 'UF inválida',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _senhaCtrl,
                      obscureText: _obscureSenha,
                      decoration:
                          _decoracao(
                            label: 'Senha',
                            icon: Icons.lock_outline,
                          ).copyWith(
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
                                  _obscureConfirmarSenha =
                                      !_obscureConfirmarSenha;
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

                        if (v != _senhaCtrl.text) {
                          return 'As senhas não conferem';
                        }

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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
          ],
        ),
      ),
    );
  }
}
