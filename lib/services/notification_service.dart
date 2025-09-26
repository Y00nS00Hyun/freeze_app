// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotiService {
  NotiService._();
  static final NotiService I = NotiService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // 알림 탭 이벤트 스트림
  final StreamController<String?> onTap = StreamController<String?>.broadcast();

  // Android 채널 설정
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'channel_main',
        'Main Notifications',
        channelDescription: '기본 알림 채널',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

  /// 초기화 (main.dart에서 앱 시작 전에 호출)
  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    // 타임존 초기화 (스케줄 알림에 필요)
    tz.initializeTimeZones();

    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initIOS = DarwinInitializationSettings();
    const settings = InitializationSettings(android: initAndroid, iOS: initIOS);

    // Android 13+ 알림 권한 요청
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        onTap.add(r.payload);
        if (navigatorKey?.currentState != null && r.payload != null) {
          // 필요하면 알림 탭 시 라우트 이동 처리
          // navigatorKey!.currentState!.pushNamed('/event', arguments: r.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 앱이 알림으로 시작된 경우 처리
    final details = await _plugin.getNotificationAppLaunchDetails();
    if ((details?.didNotificationLaunchApp ?? false) &&
        details?.notificationResponse?.payload != null) {
      final payload = details!.notificationResponse!.payload;
      onTap.add(payload);
      // navigatorKey?.currentState?.pushNamed('/event', arguments: payload);
    }
  }

  /// 즉시 알림
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(android: _androidDetails);
    await _plugin.show(0, title, body, details, payload: payload);
  }

  /// n초 뒤 알림
  Future<void> showAfter({
    required Duration after,
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(android: _androidDetails);
    await _plugin.zonedSchedule(
      1,
      title,
      body,
      tz.TZDateTime.now(tz.local).add(after),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// 주기 알림 (예: 매 1분)
  Future<void> showPeriodic({
    required String title,
    required String body,
    String? payload,
    RepeatInterval interval = RepeatInterval.everyMinute,
  }) async {
    const details = NotificationDetails(android: _androidDetails);
    await _plugin.periodicallyShow(
      2,
      title,
      body,
      interval,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // ✅ 필수 추가
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// 백그라운드 알림 탭 콜백
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse r) {
  // 여기에 최소한의 로깅이나 백그라운드 작업만 두는 게 좋아
}
