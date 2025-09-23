// lib/pages/event_viewer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/events.dart';
import '../services/ws_client.dart';
import '../widgets/yamnet_card.dart';
import '../widgets/clova_panel.dart';
import 'yolo_page.dart';

class EventViewerPage extends StatefulWidget {
  const EventViewerPage({super.key, required this.endpoint});
  final String endpoint;

  @override
  State<EventViewerPage> createState() => _EventViewerPageState();
}

class _EventViewerPageState extends State<EventViewerPage> {
  late final WsClient _ws;

  YamnetEvent? _yam;
  ClovaEvent? _clova;
  final List<YoloEvent> _yolos = [];
  final Set<String> _yoloKeys = {};
  String _conn = '연결 준비...';

  Timer? _yamHideTimer;
  bool _showYam = true;

  // ───── 팝업 중복 방지/디바운스 필드 ─────
  bool _isPopupVisible = false;
  String? _lastPopupKey;
  DateTime _lastPopupAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _popupCooldown = Duration(seconds: 3);

  // ───── YAMNet 신뢰도 하한선(필요 시 조정) ─────
  static const double _minConfidence = 0.30;

  @override
  void initState() {
    super.initState();
    _ws = WsClient(
      widget.endpoint,
      onEvent: (evt) {
        if (!mounted) return;
        debugPrint('WS EVT => $evt');

        if (evt is YamnetEvent) {
          _onYamnet(evt);
          return;
        }
        if (evt is ClovaEvent) {
          _clova = evt;
          setState(() {});
          return;
        }
        if (evt is YoloEvent) {
          _onYolo(evt);
          return;
        }

        debugPrint('Unknown evt: $evt');
      },
      onState: (s) async {
        if (!mounted) return;
        setState(() => _conn = s);
        if (s == 'connected') {
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;
          _ws.sendJson({'action': 'subscribe', 'topic': 'public'});
          debugPrint('[WS] subscribe sent => topic=public');
        }
      },
    )..connect();
  }

  @override
  void dispose() {
    _yamHideTimer?.cancel();
    _ws.dispose();
    super.dispose();
  }

  // ───────────────── YAMNet ─────────────────
  void _onYamnet(YamnetEvent e) {
    final label = e.label.trim();
    final conf = e.confidence;
    final isValid = label.isNotEmpty && conf > 0;

    setState(() {
      _yam = e;
      _showYam = true;
    });

    _yamHideTimer?.cancel();
    if (!isValid) return;

    // 위험 판정: 서버 danger 플래그 우선, 없으면 라벨 기반 판정 + 신뢰도 하한선
    final isDanger =
        (e.danger ?? !_isNonDanger(label)) && conf >= _minConfidence;

    if (isDanger) {
      _showDangerPopup(e);

      // 5초 뒤 카드 자동 숨김(동일 이벤트일 때만)
      final captured = e.ms;
      _yamHideTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        if (_yam?.ms == captured) setState(() => _showYam = false);
      });
    }
  }

  // 팝업 표시: 중복 방지 + 쿨다운 + 다음 프레임에서 안전 호출
  void _showDangerPopup(YamnetEvent e) {
    if (!mounted) return;

    final key = '${e.ms ?? 0}:${e.label.toLowerCase()}';
    final now = DateTime.now();

    // 이미 떠 있거나, 동일 이벤트가 쿨다운 내 재도착 시 무시
    if (_isPopupVisible) return;
    if (_lastPopupKey == key && now.difference(_lastPopupAt) < _popupCooldown) {
      return;
    }

    _lastPopupKey = key;
    _lastPopupAt = now;

    // 다음 프레임에서 다이얼로그 호출(네비게이션 직후 호출 안전)
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isPopupVisible) return;

      _isPopupVisible = true;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ 비상 상황 감지', style: TextStyle(color: Colors.red)),
          content: Text(
            '라벨: ${e.label}\n'
            '신뢰도: ${(e.confidence * 100).toStringAsFixed(1)}%\n'
            '시간: ${e.ms}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      ).whenComplete(() {
        _isPopupVisible = false;
      });
    });
  }

  bool _isNonDanger(String label) {
    final s = label.toLowerCase();
    final isSpeechLike =
        s.contains('speech') ||
        s.contains('talking') ||
        s.contains('conversation') ||
        s.contains('narration') ||
        s.contains('monologue') ||
        s.contains('debate') ||
        s.contains('dialogue') ||
        s.contains('chant') ||
        s.contains('narrator') ||
        s.contains('singing') ||
        s.contains('silence');
    final isSafe = s.contains('safe');
    return isSpeechLike || isSafe;
  }

  // ───────────────── YOLO ─────────────────
  void _onYolo(YoloEvent e) {
    final ty = e.event.toLowerCase();
    if (ty == 'yolo_recording_done') return;

    final key = (e.file?.trim().isNotEmpty == true)
        ? e.file!.trim()
        : '${e.time ?? 0}:${e.label}'.toLowerCase();

    if (_yoloKeys.contains(key)) return;
    _yoloKeys.add(key);

    _yolos.insert(0, e);
    if (_yolos.length > 100) {
      final removed = _yolos.removeLast();
      final rk = (removed.file?.trim().isNotEmpty == true)
          ? removed.file!.trim()
          : '${removed.time ?? 0}:${removed.label}'.toLowerCase();
      _yoloKeys.remove(rk);
    }
    setState(() {});
  }

  // ───────────────── 기타 ─────────────────
  String? _guessBaseUrlFromEndpoint(String wsEndpoint) {
    final u = Uri.tryParse(wsEndpoint);
    if (u == null) return null;
    final scheme = (u.scheme == 'wss') ? 'https' : 'http';
    final host = u.host;
    final port = u.hasPort ? ':${u.port}' : '';
    return '$scheme://$host$port';
  }

  void _openYoloPage() {
    final base = _guessBaseUrlFromEndpoint(widget.endpoint);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YoloPage(items: _yolos, imageBaseUrl: base),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF9FBFD),
        centerTitle: true,
        title: const Text(
          'SOUND SENSE',
          style: TextStyle(
            color: Color(0xFF78B8C4),
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'YOLO 결과 보기',
            onPressed: _openYoloPage,
            icon: const Icon(Icons.photo_camera_outlined, color: Colors.grey),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.5),
          child: ColoredBox(
            color: Color(0xFF78B8C4),
            child: SizedBox(height: 1.5),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_conn, style: const TextStyle(color: Colors.grey)),
            ),
            // YAMNet 카드 (위험이면 5초 후 자동 숨김)
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: (_showYam && _yam != null)
                      ? YamnetCard(
                          key: ValueKey(
                            'yam-${_yam!.ms}-${_yam!.label}-${_yam!.confidence}',
                          ),
                          event: _yam,
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // CLOVA 텍스트 영역
            SizedBox(height: 370, child: ClovaPanel(event: _clova)),
          ],
        ),
      ),
    );
  }
}
