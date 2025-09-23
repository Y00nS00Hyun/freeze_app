// lib/services/ws_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../models/events.dart';

// ★ 조건부 import: 모바일은 io, 웹은 web 파일을 가져옴
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

  /// 연결
  void connect() {
    onState?.call('connecting');
    try {
      final uri = Uri.parse(endpoint);

      // ★ 플랫폼별 커넥터 사용 (kIsWeb 분기 불필요)
      _ch = platformConnectWs(uri);

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
    } catch (_) {}
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
