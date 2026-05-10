import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/common/coloors.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';

class XploreTab3 extends StatefulWidget {
  const XploreTab3({super.key});

  @override
  State<XploreTab3> createState() => _XploreTab3State();
}

enum DiscoverState { idle, searching, connected }

class _XploreTab3State extends State<XploreTab3>
    with SingleTickerProviderStateMixin {
  DiscoverState _state = DiscoverState.idle;
  late AnimationController _pulseController;
  bool _showActions = false;
  bool _showChat = false;
  bool _showFriendAdded = false;
  final TextEditingController _msgController = TextEditingController();
  final List<String> _messages = [];
  int _currentReaction = -1;

  final List<String> _reactions = [
    "❤️",
    "😂",
    "🔥",
    "👍",
    "👏",
    "😮",
    "😢",
    "😡"
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _startSearching() async {
    setState(() => _state = DiscoverState.searching);
    // TODO: Implement real random matching backend integration
    // For now, we stay in searching state as there are no other real users online
  }

  void _cancelSearching() {
    setState(() {
      _state = DiscoverState.idle;
      _showActions = false;
      _showChat = false;
      _messages.clear();
    });
  }

  void _nextConnection() {
    setState(() {
      _showActions = false;
      _showChat = false;
      _messages.clear();
      _state = DiscoverState.searching;
    });
    _startSearching();
  }

  void _toggleActions() {
    setState(() => _showActions = !_showActions);
  }

  void _toggleChat() {
    setState(() => _showChat = !_showChat);
  }

  void _sendMessage() {
    if (_msgController.text.isNotEmpty) {
      setState(() {
        _messages.add(_msgController.text);
        _msgController.clear();
      });
    }
  }

  void _reportUser() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User reported successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Coloors.background,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case DiscoverState.idle:
        return _buildIdleState();
      case DiscoverState.searching:
        return _buildSearchingState();
      case DiscoverState.connected:
        return _buildConnectedState();
    }
  }

  Widget _buildIdleState() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_alt_outlined,
              size: 80, color: Colors.white24),
          const SizedBox(height: 24),
          const Text(
            "Discover Random People",
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Video chat with strangers worldwide",
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _startSearching,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text("START CHATTING",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6)
                      .withOpacity(0.2 * _pulseController.value),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6)
                        .withOpacity(0.5 * _pulseController.value),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.search, size: 50, color: Colors.white),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            "Searching...",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Finding someone amazing...",
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: _cancelSearching,
            child: const Text("CANCEL",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedState() {
    return Stack(
      children: [
        // 1. Partner Video Placeholder
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.person_search,
                          size: 60, color: Colors.white24)),
                  SizedBox(height: 16),
                  Text("Looking for someone...",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  Text("Random discovery is active",
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),

        // 2. Info Overlay
        Positioned(
          top: 60,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverlayTag("Waiting...", Colors.black54),
              // Common interests tag removed until real matching is implemented
              // const SizedBox(height: 8),
              // _buildOverlayTag("Common: ?? Gaming, ?? Music", const Color(0xFF8B5CF6).withOpacity(0.7)),
            ],
          ),
        ),

        // 3. Connection Quality
        Positioned(
          top: 60,
          right: 20,
          child: Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text("Excellent",
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),

        // 4. Local Preview (Small)
        Positioned(
          bottom: _showChat ? 300 : 100,
          right: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Center(
                child: Icon(Icons.videocam_off, color: Colors.white10)),
          ),
        ),

        // 5. Chat Overlay (If enabled)
        if (_showChat)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: _messages.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(_messages[index],
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: "Say hi...",
                                hintStyle: TextStyle(color: Colors.white24),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                              icon: const Icon(Icons.send,
                                  color: Color(0xFF8B5CF6)),
                              onPressed: _sendMessage),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 6. Controls & Reactions
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reactions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _reactions
                      .asMap()
                      .entries
                      .map((e) => _reactionIcon(e.key, e.value))
                      .toList(),
                ),
                const SizedBox(height: 20),
                // Main Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _mainControl(Icons.chat_bubble_outline,
                        _showChat ? const Color(0xFF8B5CF6) : Colors.white10,
                        onTap: _toggleChat),
                    const SizedBox(width: 16),
                    _mainControl(Icons.skip_next, Colors.white10,
                        onTap: _nextConnection),
                    const SizedBox(width: 16),
                    _mainControl(
                        Icons.flag_outlined, Colors.red.withOpacity(0.1),
                        iconColor: Colors.red, onTap: _reportUser),
                    const SizedBox(width: 16),
                    _mainControl(Icons.call_end, Colors.red,
                        iconColor: Colors.white, onTap: _cancelSearching),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 7. Actions Menu (Pop up from side or bottom)
        if (_showActions)
          Positioned(
            right: 20,
            bottom: 300,
            child: Column(
              children: [
                _actionButton(Icons.person_add, "Add Friend"),
                const SizedBox(height: 12),
                _actionButton(Icons.share, "Share"),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOverlayTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _reactionIcon(int index, String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _currentReaction = index),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: _currentReaction == index
              ? const Color(0xFF8B5CF6)
              : Colors.white.withOpacity(0.1),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  Widget _mainControl(IconData icon, Color bgColor,
      {Color iconColor = Colors.white, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 28,
        backgroundColor: bgColor,
        child: Icon(icon, color: iconColor),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white10,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
