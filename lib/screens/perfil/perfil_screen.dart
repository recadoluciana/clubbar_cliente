import 'package:flutter/material.dart';

import '../../services/auth_storage.dart';
import '../login/login_screen.dart';
import '../esqueceu_senha/alterar_senha_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final authStorage = AuthStorage();

  bool carregando = true;
  String nomeCliente = '';
  int? clienteId;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    final nome = await authStorage.obterNmcliente();
    final id = await authStorage.obterClienteId();

    if (!mounted) return;

    setState(() {
      nomeCliente = nome ?? '';
      clienteId = id;
      carregando = false;
    });
  }

  Future<void> fazerLogout() async {
    await authStorage.limparToken();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logout realizado com sucesso')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void abrirPedidos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tela de pedidos será a próxima etapa')),
    );
  }

  Widget _itemAcao({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.amber).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor ?? Colors.amber.shade800),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF111111),
                  Color(0xFF1E1E1E),
                  Color(0xFF2A2A2A),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeCliente.trim().isEmpty
                            ? 'Cliente Clubbar'
                            : nomeCliente,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gerencie suas informações, e altere sua senha de acesso à conta.',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 🔒 ALTERAR SENHA
          _itemAcao(
            icon: Icons.password_rounded,
            titulo: 'Alterar Senha',
            subtitulo: 'Altere sua senha de acesso à conta',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlterarSenhaScreen()),
              );
            },
            iconColor: Colors.blue,
          ),

          // 📄 MEUS PEDIDOS
          _itemAcao(
            icon: Icons.receipt_long_outlined,
            titulo: 'Meus pedidos',
            subtitulo: 'Veja seu histórico de compras e retiradas',
            onTap: abrirPedidos,
            iconColor: Colors.blue,
          ),

          const SizedBox(height: 14),

          // 🚪 SAIR
          _itemAcao(
            icon: Icons.logout_rounded,
            titulo: 'Sair da conta',
            subtitulo: 'Encerrar sessão neste dispositivo',
            onTap: fazerLogout,
            iconColor: Colors.red,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              'No Clubbar, sua carteira mostra os itens ainda disponíveis para uso ou retirada. '
              'O histórico completo fica em “Meus pedidos”.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget itemMenu({
    required IconData icon,
    required Color corIcone,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: corIcone.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: corIcone),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
