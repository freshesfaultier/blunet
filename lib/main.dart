import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:bridgefy/bridgefy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bridgefy Emergency',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        colorScheme: ColorScheme.dark(
          primary: Colors.red.shade400,
          secondary: Colors.blue.shade400,
          surface: const Color(0xFF141921),
          background: const Color(0xFF0A0E17),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141921),
          elevation: 0,
        ),
      ),
      home: const MyHomePage(title: 'Emergency Mesh'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin
    implements BridgefyDelegate {
  final Bridgefy _bridgefy = Bridgefy();
  bool _initialized = false;
  bool _started = false;
  final List<String> _log = [];
  final List<MessageItem> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late AnimationController _pulseController;

  // Modern Emergency Messages
  final List<EmergencyMessage> _emergencyMessages = [
    EmergencyMessage('🆘', 'SOS - EMERGENCY!', const Color(0xFFDC2626)),
    EmergencyMessage('🔥', 'FIRE! Need help!', const Color(0xFFEA580C)),
    EmergencyMessage('🚑', 'Medical emergency!', const Color(0xFFDB2777)),
    EmergencyMessage('🚨', 'HELP! Urgent!', const Color(0xFFC026D3)),
    EmergencyMessage('⚠️', 'WARNING: Danger!', const Color(0xFFF59E0B)),
    EmergencyMessage('✅', 'I am safe', const Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _initializeNotifications();
    _setupBridgefy();
    _autoConnectAfterInit();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _autoConnectAfterInit() async {
    await Future.delayed(const Duration(seconds: 2));
    if (_initialized && !_started) {
      await _startBridgefy();
    }
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
    setState(() => _log.add(message));
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
      setState(() => _initialized = isInit);
      _addLog('Bridgefy initialized: $_initialized');
      if (_initialized) {
        await _startBridgefy();
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
      await Permission.bluetoothAdvertise.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.notification.request();
    } catch (e) {
      _addLog('Permission request error: $e');
    }
  }

  Future<void> _startBridgefy() async {
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
      setState(() => _started = started);
      if (_started) {
        _addLog('Bridgefy started!');
      } else {
        _addLog('Sorry! could not start bridgefy');
      }
    } catch (e) {
      _addLog('Start failed: $e');
    }
  }

  Future<void> _stopBridgefy() async {
    try {
      await _bridgefy.stop();
      final started = await _bridgefy.isStarted;
      setState(() => _started = started);
      _addLog('Bridgefy stopped');
    } catch (e) {
      _addLog('Stop failed: $e');
    }
  }

  Future<void> _checkPeers() async {
    List<String> connectedPeers = await _bridgefy.connectedPeers;
    int len = connectedPeers.length;
    _addLog('Connected peers: $len');
  }

  Future<void> _sendMessage(String messageText) async {
    if (!_started) {
      _addLog('Bridgefy not started');
      return;
    }
    if (messageText.isEmpty) {
      _addLog('Message is empty');
      return;
    }

    final data = Uint8List.fromList(messageText.codeUnits);
    try {
      await _bridgefy.send(
        data: data,
        transmissionMode: BridgefyTransmissionMode(
          type: BridgefyTransmissionModeType.mesh,
          uuid: "c224fab0-9a9e-4e47-9016-4a45de15b2e8",
        ),
      );

      setState(() {
        _messages.add(
          MessageItem(
            text: messageText,
            timestamp: DateTime.now(),
            isSent: true,
          ),
        );
      });

      _addLog('Sent: $messageText');
      _messageController.clear();

      // Scroll nach unten nach dem Senden
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      _addLog('Send failed: $e');
    }
  }

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
    final text = String.fromCharCodes(data);
    setState(() {
      _messages.add(
        MessageItem(text: text, timestamp: DateTime.now(), isSent: false),
      );
    });
    _addLog('📨 Received: $text');
    _showEmergencyNotification(text);

    // Scroll nach unten nach dem Empfangen
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141921),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _started
                    ? const Color(0xFF10B981).withOpacity(0.2)
                    : const Color(0xFF6B7280).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _started
                  ? const Icon(Icons.hub, size: 20, color: Color(0xFF10B981))
                  : FadeTransition(
                      opacity: _pulseController,
                      child: const Icon(
                        Icons.sync,
                        size: 20,
                        color: Color(0xFF6B7280),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _started ? 'Mesh Network Active' : 'Connecting...',
                    style: TextStyle(
                      fontSize: 11,
                      color: _started
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.people_outline, color: Colors.white70),
                if (_started)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF141921),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _checkPeers,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1F2937),
            onSelected: (value) {
              if (value == 'clear') {
                setState(() => _messages.clear());
                _addLog('Messages cleared');
              } else if (value == 'info') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1F2937),
                    title: const Text(
                      'Status',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      'Initialized: $_initialized\n'
                      'Started: $_started\n\n'
                      'Emergency messages trigger notifications on receiving devices.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'OK',
                          style: TextStyle(color: Color(0xFF60A5FA)),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.white70),
                    SizedBox(width: 8),
                    Text(
                      'Clear Messages',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('About', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Emergency Quick Actions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xFF141921), const Color(0xFF0A0E17)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt, size: 14, color: Color(0xFFEF4444)),
                          SizedBox(width: 4),
                          Text(
                            'QUICK ACTIONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: _emergencyMessages.map((msg) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _sendMessage(msg.message),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: msg.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: msg.color.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                msg.label,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Messages Area
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141921),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send an emergency message to get started',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141921),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 15,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (text) => _sendMessage(text),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _started
                            ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                            : [
                                const Color(0xFF374151),
                                const Color(0xFF1F2937),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: _started
                          ? [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _started
                            ? () => _sendMessage(_messageController.text.trim())
                            : null,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageItem message) {
    final timeStr = _formatTime(message.timestamp);
    final isEmergency =
        message.text.contains('SOS') ||
        message.text.contains('EMERGENCY') ||
        message.text.contains('FIRE') ||
        message.text.contains('HELP');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: message.isSent
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pfeil-Icon für empfangene Nachrichten (links)
          if (!message.isSent) ...[
            Container(
              margin: const EdgeInsets.only(right: 6, bottom: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isEmergency
                    ? const Color(0xFFDC2626).withOpacity(0.2)
                    : const Color(0xFF374151).withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isEmergency
                      ? const Color(0xFFDC2626).withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 14,
                color: isEmergency
                    ? const Color(0xFFEF4444)
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ],

          // Message Bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: message.isSent
                  ? const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    )
                  : (isEmergency
                        ? const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                          )
                        : LinearGradient(
                            colors: [
                              const Color(0xFF1F2937),
                              const Color(0xFF374151),
                            ],
                          )),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: message.isSent
                    ? const Radius.circular(20)
                    : const Radius.circular(6),
                bottomRight: message.isSent
                    ? const Radius.circular(6)
                    : const Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (message.isSent
                              ? const Color(0xFF3B82F6)
                              : (isEmergency
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF000000)))
                          .withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (message.isSent) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all,
                        size: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Pfeil-Icon für gesendete Nachrichten (rechts)
          if (message.isSent) ...[
            Container(
              margin: const EdgeInsets.only(left: 6, bottom: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 14,
                color: const Color(0xFF60A5FA),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class EmergencyMessage {
  final String label;
  final String message;
  final Color color;

  EmergencyMessage(this.label, this.message, this.color);
}

class MessageItem {
  final String text;
  final DateTime timestamp;
  final bool isSent;

  MessageItem({
    required this.text,
    required this.timestamp,
    required this.isSent,
  });
}
