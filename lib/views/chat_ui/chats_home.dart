import 'package:flutter/material.dart';
import 'package:haptext_api/models/chat_ui/chat_item.dart';
import 'package:haptext_api/widgets/chat_ui/chat_item_tile.dart';
import 'package:haptext_api/views/chat_ui/chat_screen.dart';
import 'package:haptext_api/utils/chat_ui/enums.dart';
import 'package:haptext_api/services/chat_ui/hapztext_api_service.dart';
import 'package:haptext_api/services/chat_ui/chat_api_service.dart';
import 'package:provider/provider.dart';
import 'package:haptext_api/services/chat_ui/auth_provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:haptext_api/bloc/people/cubit/people_cubit.dart';
import 'package:haptext_api/bloc/auth/cubit/auth_cubit.dart';
import 'package:haptext_api/models/searched_user_model.dart';

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
      String? token = authProvider.currentUserToken;
      String? userId = authProvider.currentUserId;

      if (token == null || token.isEmpty) {
        final authCubit = context.read<AuthCubit>();
        token = authCubit.useInfo.tokens?.auth;
        userId = authCubit.useInfo.id;
        if (token != null && token.isNotEmpty) {
          authProvider.setTokenFromSession(token, userId);
        }
      }

      if (token != null && token.isNotEmpty) {
        _apiService.setToken(token);
        _apiService.currentUserId = userId;
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
        onPressed: _showNewChatBottomSheet,
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

  void _showNewChatBottomSheet() {
    final watchPeople = context.read<PeopleCubit>();
    final followings = watchPeople.followings;
    final String? currentUserId = _apiService.currentUserId;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = followings.where((f) {
              final name = (f.username ?? f.firstName ?? '').toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "New Chat",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search contacts...",
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: filteredList.isEmpty
                            ? Center(
                                child: Text(
                                  searchQuery.isEmpty ? "No followed contacts yet." : "No contacts found.",
                                  style: const TextStyle(color: Colors.white38, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredList.length,
                                itemBuilder: (context, idx) {
                                  final contact = filteredList[idx];
                                  final name = contact.username ?? contact.firstName ?? 'User';
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: contact.profilePicture != null
                                          ? NetworkImage(contact.profilePicture!)
                                          : null,
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      child: contact.profilePicture == null
                                          ? Text(name.substring(0, 1).toUpperCase(),
                                              style: const TextStyle(color: Colors.white))
                                          : null,
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: contact.bio != null
                                        ? Text(
                                            contact.bio!,
                                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    onTap: () async {
                                      Navigator.pop(context);
                                      if (currentUserId != null && contact.userId != null) {
                                        // Show visual progress indicator if needed, or simply proceed
                                        final result = await _apiService.createConversation([
                                          currentUserId,
                                          contact.userId!,
                                        ]);
                                        if (result != null && result['data'] != null) {
                                          final conv = result['data'];
                                          final chatItem = ChatItem(
                                            id: conv['id'].toString(),
                                            name: name,
                                            lastMessage: '',
                                            chatMode: ChatMode.mixed,
                                          );
                                          _navigateToChat(chatItem);
                                        }
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
