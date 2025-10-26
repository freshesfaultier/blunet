import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bridgefy/bridgefy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

class MessageItem {
  final String text;
  final DateTime timestamp;
  final bool isSent;
  final double? latitude;
  final double? longitude;

  MessageItem({
    required this.text,
    required this.timestamp,
    required this.isSent,
    this.latitude,
    this.longitude,
  });

  // JSON Serialisierung
  Map<String, dynamic> toJson() => {
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
  };

  factory MessageItem.fromJson(Map<String, dynamic> json) => MessageItem(
    text: json['text'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    isSent: false,
    latitude: json['latitude'] as double?,
    longitude: json['longitude'] as double?,
  );

  bool get hasLocation => latitude != null && longitude != null;

  String get locationString => hasLocation
      ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
      : 'No location';
}

class EmergencyMessage {
  final String label;
  final String message;
  final Color color;

  EmergencyMessage(this.label, this.message, this.color);
}

class BridgefyController implements BridgefyDelegate {
  final Bridgefy _bridgefy = Bridgefy();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _started = false;
  final List<String> _log = [];
  final List<MessageItem> _messages = [];

  // Callbacks für UI-Updates
  final VoidCallback? onStateChanged;
  final Function(String)? onLogAdded;
  final Function(MessageItem)? onMessageReceived;
  final Function(MessageItem)? onMessageSent;

  BridgefyController({
    this.onStateChanged,
    this.onLogAdded,
    this.onMessageReceived,
    this.onMessageSent,
  });

  // Getters
  bool get initialized => _initialized;
  bool get started => _started;
  List<String> get log => List.unmodifiable(_log);
  List<MessageItem> get messages => List.unmodifiable(_messages);

  // Emergency Messages
  final List<EmergencyMessage> emergencyMessages = [
    EmergencyMessage('🆘', 'SOS - EMERGENCY!', const Color(0xFFDC2626)),
    EmergencyMessage('🔥', 'FIRE! Need help!', const Color(0xFFEA580C)),
    EmergencyMessage('🚑', 'Medical emergency!', const Color(0xFFDB2777)),
    EmergencyMessage('🚨', 'HELP! Urgent!', const Color(0xFFC026D3)),
    EmergencyMessage('⚠️', 'WARNING: Danger!', const Color(0xFFF59E0B)),
    EmergencyMessage('✅', 'I am safe', const Color(0xFF10B981)),
  ];

  Future<void> initialize() async {
    await _initializeNotifications();
    await _setupBridgefy();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );
    await Permission.notification.request();
  }

  Future<void> _showEmergencyNotification(String message) async {
    Priority priority = Priority.high;
    Importance importance = Importance.high;
    String channelId = 'emergency_messages';
    String channelName = 'Emergency Messages';

    if (message.contains('SOS') ||
        message.contains('EMERGENCY') ||
        message.contains('FIRE')) {
      priority = Priority.max;
      importance = Importance.max;
      channelId = 'critical_emergency';
      channelName = 'Critical Emergency';
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Emergency messages from nearby users',
          importance: importance,
          priority: priority,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          ongoing: message.contains('SOS') || message.contains('FIRE'),
          autoCancel: false,
          styleInformation: BigTextStyleInformation(
            message,
            contentTitle: '🚨 EMERGENCY MESSAGE',
            summaryText: 'Tap to view',
          ),
          fullScreenIntent: message.contains('SOS') || message.contains('FIRE'),
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🚨 EMERGENCY MESSAGE',
      message,
      notificationDetails,
      payload: message,
    );
  }

  void _addLog(String message) {
    _log.add(message);
    onLogAdded?.call(message);
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF1F2937),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  Future<void> _setupBridgefy() async {
    await _requestPermissions();
    try {
      await _bridgefy.initialize(
        apiKey: "a27cf3e2-a6e3-4de8-8852-74003346cd60",
        delegate: this,
        verboseLogging: true,
      );
      final isInit = await _bridgefy.isInitialized;
      _initialized = isInit;
      onStateChanged?.call();
      _addLog('Bridgefy initialized: $_initialized');
      if (_initialized) {
        await Future.delayed(const Duration(seconds: 2));
        await start();
      }
    } catch (e) {
      _addLog('Init failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (await Permission.locationWhenInUse.isDenied) {
        await Permission.locationWhenInUse.request();
      }
      await Permission.location.request();
      await Permission.bluetoothAdvertise.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.notification.request();
    } catch (e) {
      _addLog('Permission request error: $e');
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _addLog('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _addLog('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _addLog('Location permissions are permanently denied');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      _addLog('Error getting location: $e');
      return null;
    }
  }

  Future<void> start() async {
    if (!_initialized) {
      _addLog('SDK not initialized yet');
      return;
    }
    try {
      await _bridgefy.start(
        userId: "c224fab0-9a9e-4e47-9016-4a45de15b2e8",
        propagationProfile: BridgefyPropagationProfile.standard,
      );
      final started = await _bridgefy.isStarted;
      _started = started;
      onStateChanged?.call();
      if (_started) {
        _addLog('Bridgefy started!');
      } else {
        _addLog('Sorry! could not start bridgefy');
      }
    } catch (e) {
      _addLog('Start failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _bridgefy.stop();
      final started = await _bridgefy.isStarted;
      _started = started;
      onStateChanged?.call();
      _addLog('Bridgefy stopped');
    } catch (e) {
      _addLog('Stop failed: $e');
    }
  }

  Future<void> checkPeers() async {
    List<String> connectedPeers = await _bridgefy.connectedPeers;
    int len = connectedPeers.length;
    _addLog('Connected peers: $len');
  }

  Future<void> sendMessage(
    String messageText, {
    bool includeLocation = false,
  }) async {
    if (!_started) {
      _addLog('Bridgefy not started');
      return;
    }
    if (messageText.isEmpty) {
      _addLog('Message is empty');
      return;
    }

    Position? position;
    if (includeLocation) {
      position = await _getCurrentLocation();
      if (position != null) {
        _addLog('Location: ${position.latitude}, ${position.longitude}');
      }
    }

    // Create JSON message with optional location
    final messageData = {
      'text': messageText,
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': position?.latitude,
      'longitude': position?.longitude,
    };

    final jsonString = jsonEncode(messageData);
    final data = Uint8List.fromList(utf8.encode(jsonString));

    try {
      await _bridgefy.send(
        data: data,
        transmissionMode: BridgefyTransmissionMode(
          type: BridgefyTransmissionModeType.mesh,
          uuid: "c224fab0-9a9e-4e47-9016-4a45de15b2e8",
        ),
      );

      final message = MessageItem(
        text: messageText,
        timestamp: DateTime.now(),
        isSent: true,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      _messages.add(message);
      onMessageSent?.call(message);

      _addLog('Sent: $messageText${position != null ? ' with location' : ''}');
    } catch (e) {
      _addLog('Send failed: $e');
    }
  }

  void clearMessages() {
    _messages.clear();
    onStateChanged?.call();
    _addLog('Messages cleared');
  }

  // BridgefyDelegate Implementation
  @override
  void bridgefyDidSendMessage({required String messageID}) {
    _addLog('Message sent: $messageID');
  }

  @override
  void bridgefyDidFailSendingMessage({
    required String messageID,
    BridgefyError? error,
  }) {
    _addLog('Send failed: ${error?.toString() ?? "unknown"}');
  }

  @override
  void bridgefyDidReceiveData({
    required Uint8List data,
    required String messageId,
    required BridgefyTransmissionMode transmissionMode,
  }) {
    try {
      final jsonString = utf8.decode(data);
      final Map<String, dynamic> messageData = jsonDecode(jsonString);

      final message = MessageItem.fromJson(messageData);
      _messages.add(message);
      onMessageReceived?.call(message);

      String logText = '📨 Received: ${message.text}';
      if (message.hasLocation) {
        logText += ' (Location: ${message.locationString})';
      }
      _addLog(logText);
      _showEmergencyNotification(message.text);
    } catch (e) {
      // Fallback for old format (plain text)
      final text = String.fromCharCodes(data);
      final message = MessageItem(
        text: text,
        timestamp: DateTime.now(),
        isSent: false,
      );
      _messages.add(message);
      onMessageReceived?.call(message);
      _addLog('📨 Received: $text');
      _showEmergencyNotification(text);
    }
  }

  @override
  void bridgefyDidConnect({required String userID}) =>
      _addLog('✅ Peer connected');

  @override
  void bridgefyDidDisconnect({required String userID}) =>
      _addLog('❌ Peer disconnected');

  @override
  void bridgefyDidDestroySession() {}

  @override
  void bridgefyDidEstablishSecureConnection({required String userID}) {}

  @override
  void bridgefyDidFailToDestroySession() {}

  @override
  void bridgefyDidFailToEstablishSecureConnection({
    required String userID,
    required BridgefyError error,
  }) {}

  @override
  void bridgefyDidFailToStart({required BridgefyError error}) {}

  @override
  void bridgefyDidFailToStop({required BridgefyError error}) {}

  @override
  void bridgefyDidSendDataProgress({
    required String messageID,
    required int position,
    required int of,
  }) {}

  @override
  void bridgefyDidStart({required String currentUserID}) {}

  @override
  void bridgefyDidStop() {}

  void dispose() {
    // Cleanup if needed
  }
}
