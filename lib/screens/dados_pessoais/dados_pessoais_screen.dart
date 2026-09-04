import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/clubbar_app_bar.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/perfil_page_header.dart';

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
  final _cepCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();

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

  String _formatarCEP(String valor) {
    final numeros = _somenteNumeros(valor);
    if (numeros.length <= 5) return numeros;
    final n = numeros.length > 8 ? numeros.substring(0, 8) : numeros;
    return '${n.substring(0, 5)}-${n.substring(5)}';
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
      _telefoneCtrl.text = _formatarTelefone(
        (data['nrtelcliente'] ?? '').toString(),
      );
      _cpfCtrl.text = _formatarCPF((data['nrcpfcliente'] ?? '').toString());
      _cepCtrl.text = _formatarCEP((data['cepcliente'] ?? '').toString());
      _enderecoCtrl.text = (data['endcliente'] ?? '').toString();
      _numeroCtrl.text = (data['nrendcliente'] ?? '').toString();
      _complementoCtrl.text = (data['complcliente'] ?? '').toString();
      _bairroCtrl.text = (data['bairrocliente'] ?? '').toString();
      _cidadeCtrl.text = (data['cidadecliente'] ?? '').toString();
      _ufCtrl.text = (data['ufcliente'] ?? '').toString().toUpperCase();
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
        endereco: _enderecoCtrl.text.trim(),
        numero: _numeroCtrl.text.trim(),
        complemento: _complementoCtrl.text.trim(),
        bairro: _bairroCtrl.text.trim(),
        cep: _somenteNumeros(_cepCtrl.text),
        cidade: _cidadeCtrl.text.trim(),
        uf: _ufCtrl.text.trim().toUpperCase(),
      );

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Dados atualizados com sucesso.');

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, 'Erro ao atualizar dados.');
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
      appBar: const ClubbarAppBar(mostrarVoltar: true),

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
              child: Column(
                children: [
                  const PerfilPageHeader(subtitulo: 'Dados pessoais'),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                      children: [
                        TextFormField(
                          controller: _nomeCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _decoracao(
                            label: 'Nome completo',
                            icon: Icons.person_outline,
                          ),
                          validator: (value) {
                            final v = value?.trim() ?? '';

                            if (v.isEmpty) {
                              return 'Informe seu nome';
                            }

                            if (v.length < 3) {
                              return 'Nome muito curto';
                            }

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

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'O e-mail de acesso não pode ser alterado nesta tela.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
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

                            if (numeros.isEmpty) {
                              return null;
                            }

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

                            if (v.isEmpty) {
                              return null;
                            }

                            if (!_validarCPF(v)) {
                              return 'CPF inválido';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 22),

                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.location_on_outlined,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Endereço',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Opcional. Você também poderá informá-lo no primeiro pagamento com cartão.',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _cepCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _decoracao(
                                    label: 'CEP',
                                    icon: Icons.markunread_mailbox_outlined,
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
                                  },
                                  validator: (value) {
                                    final numeros = _somenteNumeros(
                                      value ?? '',
                                    );
                                    if (numeros.isNotEmpty &&
                                        numeros.length != 8) {
                                      return 'CEP inválido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _enderecoCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _decoracao(
                                    label: 'Logradouro',
                                    icon: Icons.signpost_outlined,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _numeroCtrl,
                                        keyboardType:
                                            TextInputType.streetAddress,
                                        decoration: _decoracao(
                                          label: 'Número',
                                          icon: Icons.numbers,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _complementoCtrl,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        decoration: _decoracao(
                                          label: 'Complemento',
                                          icon: Icons.apartment_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _bairroCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _decoracao(
                                    label: 'Bairro',
                                    icon: Icons.location_city_outlined,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _cidadeCtrl,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: _decoracao(
                                          label: 'Cidade',
                                          icon: Icons.domain_outlined,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 94,
                                      child: TextFormField(
                                        controller: _ufCtrl,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        maxLength: 2,
                                        decoration: _decoracao(
                                          label: 'UF',
                                          icon: Icons.map_outlined,
                                        ).copyWith(counterText: ''),
                                        validator: (value) {
                                          final uf = value?.trim() ?? '';
                                          if (uf.isNotEmpty && uf.length != 2) {
                                            return 'UF inválida';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
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
                ],
              ),
            ),
    );
  }
}
