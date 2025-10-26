import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:bridgefy/bridgefy.dart';
import 'package:permission_handler/permission_handler.dart'; // optional

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bridgefy Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Bridgefy Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// Implementiere das BridgefyDelegate
class _MyHomePageState extends State<MyHomePage> implements BridgefyDelegate {
  final Bridgefy _bridgefy = Bridgefy();
  bool _initialized = false;
  bool _started = false;
  int _counter = 0;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _setupBridgefy();
  }

  // initState darf nicht async sein → separater async Initializer
  Future<void> _setupBridgefy() async {
    // optional: Request permissions (Android)
    await _requestPermissions();

    try {
      await _bridgefy.initialize(
        apiKey: "a27cf3e2-a6e3-4de8-8852-74003346cd60", // <--- hier ersetzen
        delegate: this,
        verboseLogging: true,
      );
      final isInit = await _bridgefy.isInitialized;
      setState(() {
        _initialized = isInit;
        _log.add('Bridgefy initialized: $_initialized');
      });
    } catch (e) {
      setState(() => _log.add('Init failed: $e'));
    }
  }

  // Beispiel: Permissions anfragen (vereinfacht)
  Future<void> _requestPermissions() async {
    // Für Android: eventuell BLUETOOTH* und LOCATION anfragen
    // permission_handler bietet abstrahierte Permissions; prüfe die Lib-Dokumentation
    try {
      if (await Permission.locationWhenInUse.isDenied) {
        await Permission.locationWhenInUse.request();
      }
      await Permission.bluetoothAdvertise.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      // Bei Bedarf: zusätzliche Bluetooth-Requests (abhängig von permission_handler version & Plattform)
    } catch (e) {
      _log.add('Permission request error: $e');
    }
  }

  Future<void> _startBridgefy() async {
    if (!_initialized) {
      _log.add('SDK not initialized yet');
      setState(() {});
      return;
    }
    try {
      // optional custom userId, hier automatisch generiert wenn leer
      await _bridgefy.start(
        userId: "c224fab0-9a9e-4e47-9016-4a45de15b2e8",
        propagationProfile: BridgefyPropagationProfile.standard,
      );
      final started = await _bridgefy.isStarted;
      setState(() {
        _started = started;
        _log.add('Bridgefy started: $_started');
      });
    } catch (e) {
      setState(() => _log.add('Start failed: $e'));
    }
  }

  Future<void> _stopBridgefy() async {
    try {
      await _bridgefy.stop();
      final started = await _bridgefy.isStarted;
      setState(() {
        _started = started;
        _log.add('Bridgefy stopped');
      });
    } catch (e) {
      setState(() => _log.add('Stop failed: $e'));
    }
  }

  Future<void> _checkPeers() async {
    List<String> connectedPeers = await _bridgefy.connectedPeers;
    int len = connectedPeers.length;
    setState(() => _log.add('connected peers: $len'));
  }

  // Beispiel: Daten senden (Broadcast)
  Future<void> _sendMessage() async {
    if (!_started) {
      setState(() => _log.add('Bridgefy not started'));
      return;
    }

    final data = Uint8List.fromList(
      'Hello from Flutter ${++_counter}'.codeUnits,
    );
    try {
      final lastMessageId = await _bridgefy.send(
        data: data,
        transmissionMode: BridgefyTransmissionMode(
          type: BridgefyTransmissionModeType.mesh,
          uuid: "c224fab0-9a9e-4e47-9016-4a45de15b2e8"
        ),
      );
      setState(() => _log.add('Sent message id: $lastMessageId'));
    } catch (e) {
      setState(() => _log.add('Send failed: $e'));
    }
  }

  // -------------------
  // BridgefyDelegate Methoden (callbacks vom SDK)
  // -------------------
  @override
  void bridgefyDidSendMessage({required String messageID}) {
    setState(() => _log.add('DidSendMessage: $messageID'));
  }

  @override
  void bridgefyDidFailSendingMessage({
    required String messageID,
    BridgefyError? error,
  }) {
    setState(
      () => _log.add(
        'DidFailSendingMessage: $messageID error: ${error?.toString() ?? "unknown"}',
      ),
    );
  }

  @override
  void bridgefyDidReceiveData({
    required Uint8List data,
    required String messageId,
    required BridgefyTransmissionMode transmissionMode,
  }) {
    final text = String.fromCharCodes(data);
    setState(() => _log.add('Received ($messageId): $text'));
  }

  @override
  void bridgefyDidConnect({required String userID}) {
    setState(() => _log.add('Connected: $userID'));
  }

  @override
  void bridgefyDidDisconnect({required String userID}) {
    setState(() => _log.add('Disconnected: $userID'));
  }

  // Manche Implementierungen haben noch weitere Callbacks; implementiere bei Bedarf.

  // -------------------
  // UI
  // -------------------
  void _incrementCounter() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _startBridgefy,
                  child: const Text('Start Bridgefy'),
                ),
                ElevatedButton(
                  onPressed: _stopBridgefy,
                  child: const Text('Stop Bridgefy'),
                ),
                ElevatedButton(
                  onPressed: _sendMessage,
                  child: const Text('Send Message'),
                ),
                ElevatedButton(
                  onPressed: _checkPeers,
                  child: const Text('peers'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Initialized: $_initialized · Started: $_started'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, i) => ListTile(title: Text(_log[i])),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void bridgefyDidDestroySession() {
    // TODO: implement bridgefyDidDestroySession
  }

  @override
  void bridgefyDidEstablishSecureConnection({required String userID}) {
    // TODO: implement bridgefyDidEstablishSecureConnection
  }

  @override
  void bridgefyDidFailToDestroySession() {
    // TODO: implement bridgefyDidFailToDestroySession
  }

  @override
  void bridgefyDidFailToEstablishSecureConnection({
    required String userID,
    required BridgefyError error,
  }) {
    // TODO: implement bridgefyDidFailToEstablishSecureConnection
  }

  @override
  void bridgefyDidFailToStart({required BridgefyError error}) {
    // TODO: implement bridgefyDidFailToStart
  }

  @override
  void bridgefyDidFailToStop({required BridgefyError error}) {
    // TODO: implement bridgefyDidFailToStop
  }

  @override
  void bridgefyDidSendDataProgress({
    required String messageID,
    required int position,
    required int of,
  }) {
    // TODO: implement bridgefyDidSendDataProgress
  }

  @override
  void bridgefyDidStart({required String currentUserID}) {
    // TODO: implement bridgefyDidStart
  }

  @override
  void bridgefyDidStop() {
    // TODO: implement bridgefyDidStop
  }
}
