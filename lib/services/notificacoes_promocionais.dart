import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../firebase_options_producao.dart';
import 'api_service.dart';
import 'http_with_timeout.dart' as http;

class NotificacoesPromocionais {
  static final NotificacoesPromocionais instance = NotificacoesPromocionais._();
  NotificacoesPromocionais._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _notificacaoLocal =
      FlutterLocalNotificationsPlugin();
  bool _notificacaoLocalInicializada = false;
  String? _sessao;
  int _geracao = 0;
  Future<bool>? _inicializacao;
  Future<void> _operacoes = Future<void>.value();

  Future<void> _serializar(Future<void> Function() tarefa) {
    final resultado = _operacoes.then((_) => tarefa());
    _operacoes = resultado.catchError((_) {});
    return resultado;
  }

  Future<bool> _inicializar() async {
    if (_inicializacao != null) return _inicializacao!;
    final tarefa = _criarFirebase();
    _inicializacao = tarefa;
    try {
      return await tarefa;
    } catch (_) {
      _inicializacao = null;
      rethrow;
    }
  }

  Future<bool> _criarFirebase() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    if (_messaging != null) return true;
    final app = await PackageInfo.fromPlatform();
    if (app.packageName != 'br.com.clubbar.cliente') return false;
    final options = defaultTargetPlatform == TargetPlatform.iOS
        ? firebaseIosProduction
        : firebaseAndroidProduction;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    _messaging = FirebaseMessaging.instance;
    await _inicializarNotificacaoLocal();
    FirebaseMessaging.onMessage.listen(_exibirMensagemEmPrimeiroPlano);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    _messaging!.onTokenRefresh.listen((token) {
      final sessao = _sessao;
      final geracao = _geracao;
      if (sessao != null) {
        unawaited(
          _serializar(() async {
            if (geracao == _geracao && _sessao == sessao) {
              await _registrar(token, sessao);
            }
          }).catchError((_) {}),
        );
      }
    });
    return true;
  }

  Future<void> _inicializarNotificacaoLocal() async {
    if (_notificacaoLocalInicializada) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notificacaoLocal.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _notificacaoLocal
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'promocoes',
        'Promoções',
        description: 'Ofertas e promoções dos estabelecimentos favoritos.',
        importance: Importance.high,
      ),
    );
    _notificacaoLocalInicializada = true;
  }

  Future<void> _exibirMensagemEmPrimeiroPlano(RemoteMessage mensagem) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final notificacao = mensagem.notification;
    if (notificacao == null) return;
    await _notificacaoLocal.show(
      mensagem.hashCode,
      notificacao.title ?? 'Nova promoção',
      notificacao.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'promocoes',
          'Promoções',
          channelDescription:
              'Ofertas e promoções dos estabelecimentos favoritos.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> ativar(String sessao, {bool solicitarPermissao = false}) async {
    final geracao = ++_geracao;
    if (!await _inicializar()) {
      if (solicitarPermissao) {
        throw Exception('Notificações disponíveis no aplicativo para celular.');
      }
      return;
    }
    if (geracao != _geracao) return;
    _sessao = sessao;
    final estado = solicitarPermissao
        ? await _messaging!.requestPermission()
        : await _messaging!.getNotificationSettings();
    if (estado.authorizationStatus != AuthorizationStatus.authorized &&
        estado.authorizationStatus != AuthorizationStatus.provisional) {
      if (solicitarPermissao) {
        throw Exception(
          'Permita as notificações nas configurações do celular.',
        );
      }
      return;
    }
    String? apns;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var tentativa = 0; tentativa < 5; tentativa++) {
        if (geracao != _geracao) return;
        apns = await _messaging!.getAPNSToken();
        if (apns != null) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    if (defaultTargetPlatform == TargetPlatform.iOS && apns == null) {
      if (solicitarPermissao) {
        throw Exception(
          'Não foi possível ativar as notificações agora. Tente novamente.',
        );
      }
      return;
    }
    final token = await _messaging!.getToken();
    if (geracao != _geracao) return;
    if (token == null || token.isEmpty) {
      if (solicitarPermissao) {
        throw Exception(
          'Não foi possível registrar este aparelho. Tente novamente.',
        );
      }
      return;
    }
    await _serializar(() async {
      if (geracao == _geracao && _sessao == sessao) {
        await _registrar(token, sessao);
      }
    });
  }

  Future<void> _registrar(String token, String sessao) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/clientes/me/dispositivos-promocao'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessao',
      },
      body: jsonEncode({
        'token': token,
        'plataforma': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Não foi possível registrar este aparelho.');
    }
  }

  Future<void> encerrar(String sessao) async {
    ++_geracao;
    _sessao = null;
    if (_messaging == null) return;
    await _serializar(() => _removerDispositivo(sessao));
  }

  Future<void> testar(String sessao) async {
    await ativar(sessao, solicitarPermissao: true);
    final token = await _messaging?.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Não foi possível registrar este aparelho.');
    }
    final response = await http.post(
      Uri.parse(
        '${ApiService.baseUrl}/clientes/me/dispositivos-promocao/teste',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessao',
      },
      body: jsonEncode({
        'token': token,
        'plataforma': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Não foi possível enviar a notificação de teste agora.');
    }
  }

  Future<void> _removerDispositivo(String sessao) async {
    final token = await _messaging!.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/clientes/me/dispositivos-promocao/remover',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessao',
        },
        body: jsonEncode({
          'token': token,
          'plataforma': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        }),
      );
    } finally {
      await _messaging!.deleteToken();
    }
  }
}
