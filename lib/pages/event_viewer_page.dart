// lib/pages/event_viewer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/events.dart';
import '../services/ws_client.dart';
import '../widgets/yamnet_card.dart';
import '../widgets/clova_panel.dart';
import '../services/notification_service.dart';
import '../pages/yolo_page.dart';

class EventViewerPage extends StatefulWidget {
  const EventViewerPage({super.key, required this.endpoint});
  final String endpoint;

  @override
  State<EventViewerPage> createState() => _EventViewerPageState();
}

class _EventViewerPageState extends State<EventViewerPage> {
  late final WsClient _ws;

  YamnetEvent? _yam;
  YamnetEvent? _holdYam;
  ClovaEvent? _clova;
  final List<YoloEvent> _yolos = [];
  final Set<String> _yoloKeys = {};
  String _conn = '연결 준비...';

  Timer? _yamHideTimer;

  // YAMNet 위험 알림 쿨다운
  String? _lastNotiKey;
  DateTime _lastNotiAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _notiCooldown = Duration(seconds: 3);

  // YAMNet 위험 유지
  DateTime? _dangerHoldUntil;
  static const Duration _dangerHold = Duration(seconds: 7);

  // Clova(음성 인식) 알림 쿨다운
  String? _lastClovaText;
  DateTime _lastClovaNotiAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _clovaNotiCooldown = Duration(seconds: 2);

  static const double _minConfidence = 0.30;

  bool get _isHolding =>
      _dangerHoldUntil != null && DateTime.now().isBefore(_dangerHoldUntil!);

  @override
  void initState() {
    super.initState();
    _ws = WsClient(
      widget.endpoint,
      onEvent: (evt) {
        if (!mounted) return;

        // evt를 Map으로 변환(Whisper->Clova 브리지 처리용)
        Map<String, dynamic>? m;
        try {
          m = (evt as dynamic).toJson();
        } catch (_) {
          // 무시
        }

        // Whisper transcript를 ClovaEvent로 변환
        if (m != null &&
            m['source'] == 'whisper' &&
            m['event'] == 'transcript') {
          final txt = (m['transcript'] ?? '').toString();
          debugPrint('[UI] Whisper->Clova text="$txt"');

          setState(
            () => _clova = ClovaEvent(
              event: 'transcript',
              source: 'clova',
              text: txt,
            ),
          );

          // 🔔 Clova 알림
          _maybeNotifyClova(txt);
          return;
        }

        // 기존 분기
        if (evt is YamnetEvent) {
          _onYamnet(evt);
          return;
        }

        if (evt is ClovaEvent) {
          debugPrint('[UI] ClovaEvent text="${evt.text}"');
          setState(() => _clova = evt);

          // 🔔 Clova 알림
          _maybeNotifyClova(evt.text ?? '');
          return;
        }

        if (evt is YoloEvent) {
          _onYolo(evt);
          return;
        }
      },
      onState: (s) async {
        if (!mounted) return;
        setState(() => _conn = s);
        if (s == 'connected') {
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;
          _ws.sendJson({'action': 'subscribe', 'topic': 'public'});
          _ws.sendJson({'action': 'subscribe', 'topic': 'app'});
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

  // Clova(음성 인식) 알림 로직
  void _maybeNotifyClova(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;

    // ✅ 점만 있는 텍스트는 알림 제외 (예: ".", "..", "...")
    if (RegExp(r'^\.+$').hasMatch(text)) return;

    final now = DateTime.now();
    final keyChanged = _lastClovaText != text;
    final timeOk = now.difference(_lastClovaNotiAt) >= _clovaNotiCooldown;

    if (keyChanged || timeOk) {
      _lastClovaText = text;
      _lastClovaNotiAt = now;
      NotiService.I.showNow(title: '🗣️ 음성 인식', body: text);
    }
  }

  // YAMNet 처리
  void _onYamnet(YamnetEvent e) {
    final label = e.label.trim().isEmpty ? 'Unknown' : e.label.trim();
    final conf = e.confidence;
    final isDanger =
        (e.danger ?? !_isNonDanger(label)) && conf >= _minConfidence;

    if (_isHolding && !isDanger) return;

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

    if (isDanger) {
      _holdYam = _yam;
      _dangerHoldUntil = DateTime.now().add(_dangerHold);

      _yamHideTimer?.cancel();
      _yamHideTimer = Timer(_dangerHold, () {
        if (!mounted) return;
        _dangerHoldUntil = null;
      });

      // 위험 알림(쿨다운)
      final key = '${e.ms ?? 0}:${label.toLowerCase()}';
      final now = DateTime.now();
      if (!(_lastNotiKey == key &&
          now.difference(_lastNotiAt) < _notiCooldown)) {
        _lastNotiKey = key;
        _lastNotiAt = now;
        final percent = (conf * 100).toStringAsFixed(0);
        NotiService.I.showNow(
          title: '⚠️ 비상 상황 감지',
          body: '$label · 신뢰도 $percent%',
        );
      }
    }
    setState(() {});
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

  // ────────────────────────────────────────────────────────────────────────────
  // YOLO 처리 (알림 없음)
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

  // ────────────────────────────────────────────────────────────────────────────

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
    final h = MediaQuery.of(context).size.height;
    final yamHeight = (h * 0.50).clamp(380.0, 560.0);
    final displayed = _isHolding ? _holdYam : _yam;

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
            const SizedBox(height: 12),
            SizedBox(
              height: yamHeight,
              child: Center(
                child: AnimatedOpacity(
                  opacity: (displayed != null) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: YamnetCard(event: displayed),
                  ),
                ),
              ),
            ),
            Expanded(child: ClovaPanel(event: _clova)),
          ],
        ),
      ),
    );
  }
}
