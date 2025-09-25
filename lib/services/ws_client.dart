// lib/services/ws_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../models/events.dart';
import 'ws_connector_io.dart' if (dart.library.html) 'ws_connector_web.dart';

typedef EventHandler = void Function(EventBase evt);
typedef StateHandler = void Function(String state);

class WsClient {
  WsClient(this.endpoint, {this.onEvent, this.onState});

  final String endpoint;
  final EventHandler? onEvent;
  final StateHandler? onState;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _retry;

  void connect() {
    onState?.call('connecting');
    try {
      final uri = Uri.parse(endpoint);
      debugPrint('[WS] connect → $uri');

      _ch = platformConnectWs(uri);

      _sub = _ch!.stream.listen(
        _onMessage,
        onDone: () {
          debugPrint('[WS] onDone');
          onState?.call('disconnected');
          _scheduleReconnect();
        },
        onError: (e, st) {
          debugPrint('[WS] onError $e\n$st');
          onState?.call('error');
          _scheduleReconnect();
        },
      );

      onState?.call('connected');
    } catch (e) {
      debugPrint('[WS] connect error: $e');
      onState?.call('error');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    onState?.call('receiving');
    try {
      final text = (data is List<int>) ? utf8.decode(data) : data.toString();
      debugPrint('[WS][RAW] $text');

      final obj = json.decode(text);

      if (obj is Map<String, dynamic>) {
        final evt = EventBase.fromJson(obj);
        debugPrint(
          '[WS][ROUTED] ${evt.runtimeType} src=${evt.source} ev=${evt.event}',
        );
        onEvent?.call(evt);
      } else if (obj is List) {
        for (final it in obj) {
          if (it is Map<String, dynamic>) {
            final evt = EventBase.fromJson(it);
            debugPrint(
              '[WS][ROUTED.list] ${evt.runtimeType} src=${evt.source} ev=${evt.event}',
            );
            onEvent?.call(evt);
          }
        }
      } else {
        onEvent?.call(UnknownEvent({'raw': obj}));
      }
    } catch (e, st) {
      debugPrint('[WS][onMessage][ERROR] $e\n$st\n[data]=$data');
    }
  }

  void sendJson(Map<String, dynamic> data) => sendString(jsonEncode(data));

  void sendString(String s) {
    try {
      _ch?.sink.add(s);
      debugPrint('[WS] → $s');
    } catch (e) {
      debugPrint('[WS] send error: $e');
    }
  }

  void _scheduleReconnect() {
    _retry?.cancel();
    onState?.call('reconnecting');
    _retry = Timer(const Duration(seconds: 3), connect);
  }

  Future<void> dispose() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    try {
      await _ch?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _retry?.cancel();
  }
}
