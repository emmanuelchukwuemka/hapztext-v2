import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:haptext_api/exports.dart';
import 'package:haptext_api/common/coloors.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';

class XploreTab3 extends StatefulWidget {
  const XploreTab3({super.key});

  @override
  State<XploreTab3> createState() => _XploreTab3State();
}

enum DiscoverState { idle, searching, connected }

class MockDiscoverProfile {
  final String name;
  final String avatar;
  final String interests;
  final List<String> chatMessages;

  MockDiscoverProfile({
    required this.name,
    required this.avatar,
    required this.interests,
    required this.chatMessages,
  });
}

class _XploreTab3State extends State<XploreTab3>
    with SingleTickerProviderStateMixin {
  DiscoverState _state = DiscoverState.idle;
  late AnimationController _pulseController;
  bool _showActions = false;
  bool _showChat = false;
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

  // Matchmaking variables
  Timer? _searchTimer;
  int _currentProfileIndex = 0;
  int _currentMessageIndex = 0;
  bool _isFriendAdded = false;

  List<Map<String, dynamic>> _realProfiles = [];
  bool _isLoadingRealProfiles = false;

  final List<MockDiscoverProfile> _mockProfiles = [
    MockDiscoverProfile(
      name: "Sophia",
      avatar: "assets/images/placeholder.jpg",
      interests: "🎨 Art, 🎮 Gaming, 🎧 Music",
      chatMessages: [
        "Hey! Nice to meet you here! 😊",
        "I'm Sophia, currently studying art. What about you?",
        "That's so cool! I love chatting with people here.",
        "Haha totally! What are your hobbies?",
        "Wow, we have so much in common! Let's add each other!",
      ],
    ),
    MockDiscoverProfile(
      name: "Marcus",
      avatar: "assets/images/placeholder.jpg",
      interests: "⚽ Sports, 🍔 Foodie, ✈️ Travel",
      chatMessages: [
        "Yo! What's up? ✌️",
        "Just got back from a football match. You like sports?",
        "Nice! I'm planning my next trip to Europe soon.",
        "Definitely, life is too short to stay in one place!",
        "Hey, you're awesome, let's connect as friends!",
      ],
    ),
    MockDiscoverProfile(
      name: "Emma",
      avatar: "assets/images/placeholder.jpg",
      interests: "📚 Reading, 🐱 Cats, ☕ Coffee",
      chatMessages: [
        "Hi there! 🌸",
        "Drinking some caramel macchiato right now. What's your go-to drink?",
        "Oh, that sounds delicious! 😋",
        "Do you have any pets? I have two adorable cats!",
        "You seem super friendly! Let's be friends!",
      ],
    ),
  ];

  Future<void> _loadRealProfiles() async {
    if (_isLoadingRealProfiles) return;
    setState(() {
      _isLoadingRealProfiles = true;
    });
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        final List<dynamic> rows = await client
            .from('profiles')
            .select()
            .neq('user_id', currentUser.id)
            .limit(20);
        
        setState(() {
          _realProfiles = List<Map<String, dynamic>>.from(rows);
        });
      }
    } catch (e) {
      debugPrint('Error loading discover profiles: $e');
    } finally {
      setState(() {
        _isLoadingRealProfiles = false;
      });
    }
  }

  String _getMatchName() {
    if (_realProfiles.isNotEmpty) {
      final profile = _realProfiles[_currentProfileIndex];
      final username = profile['username']?.toString();
      final firstName = profile['first_name']?.toString();
      final lastName = profile['last_name']?.toString();
      if (username != null && username.isNotEmpty) return username;
      if (firstName != null && firstName.isNotEmpty) {
        return "$firstName ${lastName ?? ''}".trim();
      }
      return 'User';
    }
    return _mockProfiles[_currentProfileIndex].name;
  }

  String _getMatchAvatar() {
    if (_realProfiles.isNotEmpty) {
      final profile = _realProfiles[_currentProfileIndex];
      return profile['profile_picture']?.toString() ?? "assets/images/placeholder.jpg";
    }
    return _mockProfiles[_currentProfileIndex].avatar;
  }

  String _getMatchInterests() {
    if (_realProfiles.isNotEmpty) {
      final profile = _realProfiles[_currentProfileIndex];
      return profile['bio']?.toString() ?? "No bio yet";
    }
    return _mockProfiles[_currentProfileIndex].interests;
  }

  String _getMatchUserId() {
    if (_realProfiles.isNotEmpty) {
      final profile = _realProfiles[_currentProfileIndex];
      return profile['user_id']?.toString() ?? '';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadRealProfiles();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pulseController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _startSearching() {
    setState(() {
      _state = DiscoverState.searching;
      _showActions = false;
      _showChat = false;
      _isFriendAdded = false;
      _messages.clear();
      _currentMessageIndex = 0;
    });

    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final profilesCount = _realProfiles.isNotEmpty ? _realProfiles.length : _mockProfiles.length;
        setState(() {
          _state = DiscoverState.connected;
          _showActions = true;
          // Rotate to next profile
          _currentProfileIndex = (_currentProfileIndex + 1) % profilesCount;
        });

        final name = _getMatchName();
        final text = _realProfiles.isNotEmpty
            ? "Hey! Nice to connect with you!"
            : _mockProfiles[_currentProfileIndex].chatMessages[0];

        setState(() {
          _messages.add("System: Connected with $name");
        });
        
        Timer(const Duration(milliseconds: 1000), () {
          if (mounted && _state == DiscoverState.connected) {
            setState(() {
              _messages.add("$name: $text");
              _currentMessageIndex = 1;
            });
          }
        });
      }
    });
  }

  void _cancelSearching() {
    _searchTimer?.cancel();
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
      final userText = _msgController.text.trim();
      setState(() {
        _messages.add("You: $userText");
        _msgController.clear();
      });

      // Simulate matched user response
      final name = _getMatchName();
      if (_realProfiles.isEmpty) {
        final profile = _mockProfiles[_currentProfileIndex];
        if (_currentMessageIndex < profile.chatMessages.length) {
          final reply = profile.chatMessages[_currentMessageIndex];
          _currentMessageIndex++;
          Timer(const Duration(milliseconds: 1500), () {
            if (mounted && _state == DiscoverState.connected) {
              setState(() {
                _messages.add("${profile.name}: $reply");
              });
              // Trigger a random reaction from them
              final random = Random();
              if (random.nextBool()) {
                setState(() {
                  _currentReaction = random.nextInt(_reactions.length);
                });
              }
            }
          });
        }
      } else {
        // Real profile simulation
        if (_currentMessageIndex == 1) {
          _currentMessageIndex = 2;
          Timer(const Duration(milliseconds: 1500), () {
            if (mounted && _state == DiscoverState.connected) {
              setState(() {
                _messages.add("$name: That's awesome! Let's be friends! Check out my profile.");
              });
            }
          });
        }
      }
    }
  }

  void _reportUser() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User reported successfully")),
    );
    _nextConnection();
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
    final name = _getMatchName();
    final interests = _getMatchInterests();
    return Stack(
      children: [
        // 1. Partner Video / Ambient Simulation
        Positioned.fill(
          child: _buildMatchedUserAmbientWidget(),
        ),

        // 2. Info Overlay
        Positioned(
          top: 60,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverlayTag("Matched: $name", const Color(0xFF8B5CF6)),
              const SizedBox(height: 8),
              _buildOverlayTag(interests, Colors.black54),
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
                _actionButton(
                  Icons.person_add,
                  "Add Friend",
                  onTap: () {
                    if (!_isFriendAdded) {
                      setState(() {
                        _isFriendAdded = true;
                      });
                      final matchedUserId = _getMatchUserId();
                      if (matchedUserId.isNotEmpty) {
                        context.read<PeopleCubit>().followUser(userId: matchedUserId);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Friend request sent to $name! ✨",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: const Color(0xFF8B5CF6),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _actionButton(
                  Icons.share,
                  "Share",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Link copied to clipboard!")),
                    );
                  },
                ),
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

  Widget _buildMatchedUserAmbientWidget() {
    final name = _getMatchName();
    final avatar = _getMatchAvatar();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F0C20),
            Color(0xFF1B1437),
            Color(0xFF050308),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dynamic pulsing backdrop waves
          Center(
            child: Opacity(
              opacity: 0.1,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + 0.2 * _pulseController.value,
                    child: const Icon(
                      Icons.circle,
                      size: 350,
                      color: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing glow outer ring around partner avatar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                      blurRadius: 50,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: avatar.startsWith('http')
                      ? NetworkImage(avatar)
                      : AssetImage(avatar) as ImageProvider,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "Live Video Match",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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

  Widget _actionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: _isFriendAdded && label == "Add Friend"
                ? Colors.green
                : Colors.white10,
            child: Icon(
              _isFriendAdded && label == "Add Friend" ? Icons.check : icon,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isFriendAdded && label == "Add Friend" ? "Added" : label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
