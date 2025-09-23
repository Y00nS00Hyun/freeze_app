import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/events.dart';
import '../services/ws_client.dart';
import '../widgets/yamnet_card.dart';
import '../widgets/clova_panel.dart';
import 'yolo_page.dart';
import '../services/notification_service.dart'; // ⬅ 알림

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
  String _conn = '연결 준비...'; // 화면에 표시하진 않지만 내부 상태는 유지

  Timer? _yamHideTimer;
  bool _showYam = true;

  // 알림 스팸 방지
  String? _lastNotiKey;
  DateTime _lastNotiAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _notiCooldown = Duration(seconds: 3);

  // YAMNet 신뢰도 하한선
  static const double _minConfidence = 0.30;

  @override
  void initState() {
    super.initState();
    _ws = WsClient(
      widget.endpoint,
      onEvent: (evt) {
        if (!mounted) return;

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
      },
      onState: (s) async {
        if (!mounted) return;
        setState(() => _conn = s); // 화면엔 안 보이지만 상태는 저장
        if (s == 'connected') {
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;
          _ws.sendJson({'action': 'subscribe', 'topic': 'public'});
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

  // ───────────── YAMNet ─────────────
  void _onYamnet(YamnetEvent e) {
    final label = e.label.trim().isEmpty ? 'Unknown' : e.label.trim();
    final conf = e.confidence;

    setState(() {
      _yam = YamnetEvent(
        event: e.event,
        source: e.source,
        label: label,
        confidence: conf,
        direction: e.direction,
        energy: e.energy,
        ms: e.ms,
        danger: e.danger,
        group: e.group,
        dbfs: e.dbfs,
        latencySec: e.latencySec,
      );
      _showYam = true;
    });

    _yamHideTimer?.cancel();

    // ✅ 비상상황일 때만 알림
    final isDanger =
        (e.danger ?? !_isNonDanger(label)) && conf >= _minConfidence;
    if (isDanger) {
      final key = '${e.ms ?? 0}:${label.toLowerCase()}';
      final now = DateTime.now();
      if (!(_lastNotiKey == key &&
          now.difference(_lastNotiAt) < _notiCooldown)) {
        _lastNotiKey = key;
        _lastNotiAt = now;
        final percent = (conf * 100).toStringAsFixed(0);
        NotiService.I.showDanger('⚠️ 비상 상황 감지', '$label · 신뢰도 $percent%');
      }

      final captured = e.ms;
      _yamHideTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        if (_yam?.ms == captured) setState(() => _showYam = false);
      });
    }
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

  // ───────────── YOLO ─────────────
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

  // ───────────── 기타 ─────────────
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
        shape: const Border(
          bottom: BorderSide(
            color: Color.fromARGB(255, 151, 198, 206),
            width: 1.3,
          ),
        ),
        title: Text(
          'SOUND SENSE',
          style: GoogleFonts.gowunDodum(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: const Color(0xFF78B8C4),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF78B8C4)),
        actions: [
          IconButton(
            tooltip: 'YOLO 결과 보기',
            onPressed: _openYoloPage,
            icon: const Icon(Icons.photo_camera_outlined, color: Colors.grey),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12), // 상단 간격만 약간
            // ⛔️ 연결 상태 텍스트는 아예 표시 안 함

            // YAMNet 카드
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

            SizedBox(height: 330, child: ClovaPanel(event: _clova)),
          ],
        ),
      ),
    );
  }
}
