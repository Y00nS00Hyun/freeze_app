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

  YamnetEvent? _yam; // 실시간 최신 이벤트
  YamnetEvent? _holdYam; // 🔒 위험 홀드용 버퍼
  ClovaEvent? _clova;
  final List<YoloEvent> _yolos = [];
  final Set<String> _yoloKeys = {};
  String _conn = '연결 준비...';

  Timer? _yamHideTimer;

  // 알림 스팸 방지
  String? _lastNotiKey;
  DateTime _lastNotiAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _notiCooldown = Duration(seconds: 3);

  // 위험 화면 최소 유지(고정) 시간
  DateTime? _dangerHoldUntil;
  static const Duration _dangerHold = Duration(seconds: 7);

  // YAMNet 신뢰도 하한선
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
        setState(() => _conn = s);
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

    final isDanger =
        (e.danger ?? !_isNonDanger(label)) && conf >= _minConfidence;

    if (_isHolding) {
      // 🔒 홀드 중엔 '안전' 업데이트는 무시 → 화면 유지
      if (!isDanger) return;
    }

    // 최신 이벤트는 항상 갱신(로그/통계용)
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
      // 🔒 위험 감지 시: 홀드 버퍼에 저장 + 5초 연장
      _holdYam = _yam;
      _dangerHoldUntil = DateTime.now().add(_dangerHold);

      _yamHideTimer?.cancel();
      _yamHideTimer = Timer(_dangerHold, () {
        if (!mounted) return;
        // 홀드 해제만; 화면은 다음 업데이트 때 자연스레 바뀜
        _dangerHoldUntil = null;
        // 원하면 자동 숨김도 가능:
        // setState(() => _holdYam = null);
      });

      // 알림(쿨다운)
      final key = '${e.ms ?? 0}:${label.toLowerCase()}';
      final now = DateTime.now();
      if (!(_lastNotiKey == key &&
          now.difference(_lastNotiAt) < _notiCooldown)) {
        _lastNotiKey = key;
        _lastNotiAt = now;
        final percent = (conf * 100).toStringAsFixed(0);
        NotiService.I.showDanger('⚠️ 비상 상황 감지', '$label · 신뢰도 $percent%');
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
    // 화면 크기에 맞춰 YAM 카드 영역 높이 동적 계산 (잘림 방지)
    final h = MediaQuery.of(context).size.height;
    final yamHeight = (h * 0.50).clamp(380.0, 560.0);

    // 🔒 홀드 중이면 _holdYam 표출, 아니면 최신 _yam
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
            const SizedBox(height: 12),

            // 카드 영역(위치 고정) + 내부 스크롤 허용(넘칠 때만)
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

            SizedBox(height: 330, child: ClovaPanel(event: _clova)),
          ],
        ),
      ),
    );
  }
}
