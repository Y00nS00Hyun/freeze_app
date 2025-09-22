// lib/services/ws_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart' as io_ws;
import 'package:web_socket_channel/html.dart' as html_ws;
import 'package:web_socket_channel/status.dart' as ws_status;

import '../models/events.dart';

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

  /// 연결
  void connect() {
    onState?.call('connecting');
    try {
      final uri = Uri.parse(endpoint);

      _ch = kIsWeb
          ? html_ws.HtmlWebSocketChannel.connect(uri.toString())
          : io_ws.IOWebSocketChannel.connect(
              uri,
              pingInterval: const Duration(seconds: 15),
            );

      _sub = _ch!.stream.listen(
        _onMessage,
        onDone: () {
          onState?.call('disconnected');
          _scheduleReconnect();
        },
        onError: (e, st) {
          onState?.call('error');
          _scheduleReconnect();
        },
      );

      onState?.call('connected');
    } catch (e) {
      onState?.call('error');
      _scheduleReconnect();
    }
  }

  /// 수신 처리
  void _onMessage(dynamic data) {
    onState?.call('receiving');
    try {
      final text = (data is List<int>) ? utf8.decode(data) : data.toString();
      final obj = json.decode(text);

      if (obj is Map<String, dynamic>) {
        onEvent?.call(EventBase.fromJson(obj));
      } else if (obj is List) {
        for (final it in obj) {
          if (it is Map<String, dynamic>) {
            onEvent?.call(EventBase.fromJson(it));
          }
        }
      } else {
        onEvent?.call(UnknownEvent({'raw': obj}));
      }
    } catch (e) {}
  }

  /// JSON 전송
  void sendJson(Map<String, dynamic> data) {
    sendString(jsonEncode(data));
  }

  /// 문자열 전송
  void sendString(String s) {
    try {
      _ch?.sink.add(s);
      debugPrint('[WS] → $s');
    } catch (e) {
      debugPrint('[WS] send error: $e');
    }
  }

  /// 재연결
  void _scheduleReconnect() {
    _retry?.cancel();
    onState?.call('reconnecting');
    _retry = Timer(const Duration(seconds: 3), connect);
  }

  /// 종료
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
