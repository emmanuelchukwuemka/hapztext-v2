import 'package:flutter/material.dart';
import 'package:haptext_api/models/chat_ui/chat_item.dart';
import 'package:haptext_api/widgets/chat_ui/chat_item_tile.dart';
import 'package:haptext_api/views/chat_ui/chat_screen.dart';
import 'package:haptext_api/utils/chat_ui/enums.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';
import 'package:haptext_api/services/chat_ui/chat_api_service.dart';
import 'package:provider/provider.dart';
import 'package:haptext_api/services/chat_ui/auth_provider.dart';

class ChatsHome extends StatefulWidget {
  const ChatsHome({super.key});

  @override
  State<ChatsHome> createState() => _ChatsHomeState();
}

class _ChatsHomeState extends State<ChatsHome> {
  bool _isPinnedExpanded = true;
  final HapzTextApiService _apiService = HapzTextApiService();
  late ChatApiService _chatApiService;
  List<ChatItem> _chats = [];

  @override
  void initState() {
    super.initState();
    _chatApiService = ChatApiService(_apiService);
    _chats = [];

    // Inject auth token and load real data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUserToken != null) {
        _apiService.setToken(authProvider.currentUserToken!);
        _apiService.currentUserId = authProvider.currentUserId;
        _loadConversations();
      }
    });
  }

  Future<void> _loadConversations() async {
    try {
      // Assuming we have a logged in user token set in _apiService somewhere globally or passed down
      // For now just fetching
      final conversations = await _chatApiService.getConversations();
      if (mounted) {
        setState(() {
          // Merge or replace. For simplicity, we can append specific API chats
          // preventing duplicates if IDs clash
          for (var conv in conversations) {
            final index = _chats.indexWhere((c) => c.id == conv.id);
            if (index != -1) {
              _chats[index] = conv;
            } else {
              _chats.add(conv);
            }
          }
        });
      }
    } catch (e) {
      print('Error loading conversations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinnedChats = _chats.where((c) => c.pinned).toList();
    final regularChats = _chats.where((c) => !c.pinned).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: ListView(
        children: [
          if (pinnedChats.isNotEmpty) ...[
            _buildSectionHeader("PINNED", _isPinnedExpanded, () {
              setState(() => _isPinnedExpanded = !_isPinnedExpanded);
            }),
            if (_isPinnedExpanded)
              ...pinnedChats.map((chat) => ChatItemTile(
                    chat: chat,
                    onTap: () => _navigateToChat(chat),
                  )),
          ],
          _buildSectionHeader("ALL MESSAGES", false, null),
          ...regularChats.map((chat) => ChatItemTile(
                chat: chat,
                onTap: () => _navigateToChat(chat),
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.teal,
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, bool isExpanded, VoidCallback? onToggle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          if (onToggle != null)
            IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }

  void _navigateToChat(ChatItem chat) async {
    final updatedChat = await Navigator.push<ChatItem>(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chat: chat),
      ),
    );

    if (updatedChat != null) {
      setState(() {
        final index = _chats.indexWhere((c) => c.id == updatedChat.id);
        if (index != -1) {
          _chats[index] = updatedChat;
        }
      });
    }
  }
}
