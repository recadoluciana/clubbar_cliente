import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../services/api_service.dart';
import '../../utils/value_formatters.dart';

const imagemRoleta = 'assets/images/roleta_promocional_sem_ponteiro.png';
const _setores = [0, 10, 20, 10, 20];

class RoletaProdutoDialog extends StatefulWidget {
  const RoletaProdutoDialog({
    super.key,
    required this.produto,
    required this.precoBase,
    required this.sortear,
    required this.confirmar,
    required this.mensagemErro,
  });

  final String produto;
  final double precoBase;
  final Future<ResultadoGiro> Function() sortear;
  final Future<void> Function(int resgateId, int precoCentavos) confirmar;
  final String Function(Object) mensagemErro;

  @override
  State<RoletaProdutoDialog> createState() => _RoletaProdutoDialogState();
}

class _RoletaProdutoDialogState extends State<RoletaProdutoDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _voltas = AnimationController.unbounded(
    vsync: this,
  );
  ResultadoGiro? _resultado;
  var _confirmando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _girar();
  }

  Future<void> _girar() async {
    _voltas.repeat(min: 0, max: 1, period: const Duration(milliseconds: 600));
    try {
      final giro = await widget.sortear();
      if (!mounted) return;
      final setor = _setores.indexOf(giro.percentual);
      final destino = _voltas.value.ceil() + 3 - setor / _setores.length;
      await _voltas
          .animateTo(
            destino,
            duration: const Duration(milliseconds: 1900),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      if (mounted) setState(() => _resultado = giro);
    } on TickerCanceled {
      return;
    } catch (e) {
      if (!mounted) return;
      _voltas.stop();
      setState(() => _erro = widget.mensagemErro(e));
    }
  }

  int _precoCentavos(int percentual) =>
      ((widget.precoBase * 100).round() * (100 - percentual) + 50) ~/ 100;

  Future<void> _confirmar() async {
    final giro = _resultado;
    if (giro == null || _confirmando) return;
    setState(() {
      _confirmando = true;
      _erro = null;
    });
    try {
      await widget.confirmar(giro.resgateId, _precoCentavos(giro.percentual));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _confirmando = false;
          _erro = widget.mensagemErro(e);
        });
      }
    }
  }

  @override
  void dispose() {
    _voltas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final giro = _resultado;
    return PopScope(
      canPop: !_confirmando,
      child: AlertDialog(
        scrollable: true,
        title: Text(widget.produto),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 220,
              child: FittedBox(
                child: SizedBox.square(
                  dimension: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _voltas,
                        child: Stack(
                          children: [
                            Image.asset(
                              imagemRoleta,
                              width: 220,
                              height: 220,
                              semanticLabel: 'Roleta de descontos',
                            ),
                            for (var i = 0; i < _setores.length; i++)
                              Positioned(
                                left:
                                    110 +
                                    52 *
                                        math.sin(
                                          2 * math.pi * i / _setores.length,
                                        ) -
                                    23,
                                top:
                                    110 -
                                    52 *
                                        math.cos(
                                          2 * math.pi * i / _setores.length,
                                        ) -
                                    13,
                                width: 46,
                                child: Transform.rotate(
                                  angle: 2 * math.pi * i / _setores.length,
                                  child: Text(
                                    '${_setores[i]}%',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        child: CustomPaint(
                          size: Size(28, 21),
                          painter: _Ponteiro(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (giro != null) ...[
              Text(
                giro.percentual == 0
                    ? 'Sem desconto neste giro'
                    : '${giro.percentual}% de desconto',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '1 unidade por ${ValueFormatters.moeda(_precoCentavos(giro.percentual) / 100)}',
              ),
            ] else if (_erro == null)
              const Text('Girando…'),
            if (_erro != null) Text(_erro!, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _confirmando
                ? null
                : () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xff533708),
            ),
            onPressed: giro != null && !_confirmando ? _confirmar : null,
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _Ponteiro extends CustomPainter {
  const _Ponteiro();

  @override
  void paint(Canvas canvas, Size size) {
    final seta = Path()
      ..moveTo(2, 2)
      ..lineTo(size.width - 2, 2)
      ..lineTo(size.width / 2, size.height - 1)
      ..close();
    canvas.drawPath(seta, Paint()..color = const Color(0xffffc739));
    canvas.drawPath(
      seta,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xff382207),
    );
  }

  @override
  bool shouldRepaint(_Ponteiro oldDelegate) => false;
}
