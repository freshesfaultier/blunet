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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Emergency Messenger'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> implements BridgefyDelegate {
  final Bridgefy _bridgefy = Bridgefy();
  bool _initialized = false;
  bool _started = false;
  int _counter = 0;
  final List<String> _log = [];
  final List<MessageItem> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Notification plugin
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Emergency quick messages
  final List<EmergencyMessage> _emergencyMessages = [
    EmergencyMessage('🆘 SOS', 'SOS - EMERGENCY!', Colors.red),
    EmergencyMessage('🔥 Fire', 'FIRE! Need help!', Colors.orange),
    EmergencyMessage('🚑 Medical', 'Medical emergency!', Colors.pink),
    EmergencyMessage(
      '🚨 Help',
      'HELP! Urgent assistance needed!',
      Colors.deepOrange,
    ),
    EmergencyMessage('⚠️ Danger', 'WARNING: Danger nearby!', Colors.amber),
    EmergencyMessage('👍 Safe', 'I am safe', Colors.green),
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupBridgefy();
    // Automatisch starten nach Initialisierung
    _autoConnectAfterInit(); // <- DIESE ZEILE HINZUGEFÜGT
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // NEU: Automatische Verbindung nach Initialisierung
  Future<void> _autoConnectAfterInit() async {
    // Warte kurz, damit die Initialisierung abgeschlossen ist
    await Future.delayed(const Duration(seconds: 2));

    if (_initialized && !_started) {
      await _startBridgefy();
    }
  }

  // Initialize notifications
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
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Request notification permissions (especially for Android 13+)
    await Permission.notification.request();
  }

  // Show emergency notification
  Future<void> _showEmergencyNotification(String message) async {
    // Determine notification priority based on message content
    Priority priority = Priority.high;
    Importance importance = Importance.high;
    String channelId = 'emergency_messages';
    String channelName = 'Emergency Messages';

    // Use max priority for critical emergencies
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
          // Make notification persistent for critical messages
          ongoing: message.contains('SOS') || message.contains('FIRE'),
          autoCancel: false,
          styleInformation: BigTextStyleInformation(
            message,
            contentTitle: '🚨 EMERGENCY MESSAGE',
            summaryText: 'Tap to view',
          ),
          // Full screen intent for critical emergencies
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
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
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
      backgroundColor: Colors.black87,
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
      setState(() {
        _initialized = isInit;
      });
      _addLog('Bridgefy initialized: $_initialized');

      if (_initialized) {
        // <- DIESE ZEILEN
        await _startBridgefy(); // <- HINZUGEFÜGT
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
      setState(() {
        _started = started;
      });
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
      setState(() {
        _started = started;
      });
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
      final lastMessageId = await _bridgefy.send(
        data: data,
        transmissionMode: BridgefyTransmissionMode(
          type: BridgefyTransmissionModeType.mesh,
          uuid: "c224fab0-9a9e-4e47-9016-4a45de15b2e8",
        ),
      );

      // Add to message history
      setState(() {
        _messages.insert(
          0,
          MessageItem(
            text: messageText,
            timestamp: DateTime.now(),
            isSent: true,
          ),
        );
      });

      _addLog('Sent: $messageText');
      _messageController.clear();
    } catch (e) {
      _addLog('Send failed: $e');
    }
  }

  // BridgefyDelegate Methods
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

    // Add to message history
    setState(() {
      _messages.insert(
        0,
        MessageItem(text: text, timestamp: DateTime.now(), isSent: false),
      );
    });

    _addLog('📨 Received: $text');

    // Show native notification for received message
    _showEmergencyNotification(text);
  }

  @override
  void bridgefyDidConnect({required String userID}) {
    _addLog('✅ Peer connected');
  }

  @override
  void bridgefyDidDisconnect({required String userID}) {
    _addLog('❌ Peer disconnected');
  }

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

  void _incrementCounter() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Message History'),
                  content: const Text(
                    'Are you sure you want to clear all messages?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _messages.clear());
                        Navigator.pop(context);
                        _addLog('Message history cleared');
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About'),
                  content: Text(
                    'Status:\n'
                    '• Initialized: $_initialized\n'
                    '• Started: $_started\n\n'
                    'Tap emergency buttons for quick messages or type custom messages below.\n\n'
                    'Emergency messages will trigger native notifications on receiving devices.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _started ? Colors.green.shade400 : Colors.grey.shade400,
                  _started ? Colors.green.shade600 : Colors.grey.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _started ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _started ? 'CONNECTED' : 'CONNECTING...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Control Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _started ? null : _startBridgefy,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _started ? _stopBridgefy : null,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Stop', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _checkPeers,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  child: const Icon(Icons.people, size: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Emergency Messages Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚡ Quick Emergency Messages',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: _emergencyMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _emergencyMessages[index];
                    return ElevatedButton(
                      onPressed: () => _sendMessage(msg.message),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: msg.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        msg.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Custom Message Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✏️ Custom Message',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          labelText: 'Type your message',
                          hintText: 'Enter message here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.message, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (text) => _sendMessage(text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          _sendMessage(_messageController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.send, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Message History Section
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Text(
                          '📋 Message History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_messages.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sent and received messages will appear here',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: _messages.length,
                            separatorBuilder: (context, index) =>
                                Divider(height: 1, color: Colors.grey.shade300),
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return _buildMessageItem(message);
                            },
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

  Widget _buildMessageItem(MessageItem message) {
    final timeStr = _formatTime(message.timestamp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Direction indicator
          Container(
            margin: const EdgeInsets.only(right: 8, top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: message.isSent
                  ? Colors.green.shade100
                  : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              message.isSent ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: message.isSent
                  ? Colors.green.shade700
                  : Colors.blue.shade700,
            ),
          ),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.isSent ? 'SENT' : 'RECEIVED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: message.isSent
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
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
