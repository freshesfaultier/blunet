import 'package:flutter/material.dart';
import 'bridgefy_controller.dart';

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
    with SingleTickerProviderStateMixin {
  late BridgefyController _controller;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _controller = BridgefyController(
      onStateChanged: () => setState(() {}),
      onLogAdded: (log) => setState(() {}),
      onMessageReceived: (message) {
        setState(() {});
        _scrollToBottom();
      },
      onMessageSent: (message) {
        setState(() {});
        _messageController.clear();
        _scrollToBottom();
      },
    );

    _controller.initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildQuickActions(),
          _buildMessagesArea(),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF141921),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _controller.started
                  ? const Color(0xFF10B981).withOpacity(0.2)
                  : const Color(0xFF6B7280).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _controller.started
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
                  _controller.started ? 'Mesh Network Active' : 'Connecting...',
                  style: TextStyle(
                    fontSize: 11,
                    color: _controller.started
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
              if (_controller.started)
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
          onPressed: _controller.checkPeers,
        ),
        _buildMenu(),
      ],
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      color: const Color(0xFF1F2937),
      onSelected: (value) {
        if (value == 'clear') {
          _controller.clearMessages();
        } else if (value == 'info') {
          _showInfoDialog();
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.white70),
              SizedBox(width: 8),
              Text('Clear Messages', style: TextStyle(color: Colors.white)),
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
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Status', style: TextStyle(color: Colors.white)),
        content: Text(
          'Initialized: ${_controller.initialized}\n'
          'Started: ${_controller.started}\n\n'
          'Emergency messages trigger notifications on receiving devices.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF60A5FA))),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141921), Color(0xFF0A0E17)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            children: _controller.emergencyMessages.map((msg) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _controller.sendMessage(msg.message),
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
    );
  }

  Widget _buildMessagesArea() {
    return Expanded(
      child: _controller.messages.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _controller.messages.length,
              itemBuilder: (context, index) {
                final message = _controller.messages[index];
                return _buildMessageBubble(message);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF141921),
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
          if (!message.isSent) _buildReceivedIcon(isEmergency),
          _buildMessageContainer(message, timeStr, isEmergency),
          if (message.isSent) _buildSentIcon(),
        ],
      ),
    );
  }

  Widget _buildReceivedIcon(bool isEmergency) {
    return Container(
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
    );
  }

  Widget _buildSentIcon() {
    return Container(
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
      child: const Icon(
        Icons.arrow_upward_rounded,
        size: 14,
        color: Color(0xFF60A5FA),
      ),
    );
  }

  Widget _buildMessageContainer(
    MessageItem message,
    String timeStr,
    bool isEmergency,
  ) {
    return Container(
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
                  : const LinearGradient(
                      colors: [Color(0xFF1F2937), Color(0xFF374151)],
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
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141921),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
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
                  onSubmitted: (text) => _controller.sendMessage(text.trim()),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _controller.started
              ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
              : [const Color(0xFF374151), const Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: _controller.started
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
          onTap: _controller.started
              ? () => _controller.sendMessage(_messageController.text.trim())
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
