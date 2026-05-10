import 'package:flutter/material.dart';
import 'package:haptext_api/models/chat_ui/chat_item.dart';
import 'package:haptext_api/utils/chat_ui/enums.dart';

class ProfilePanel extends StatefulWidget {
  final ChatItem chat;
  final Function(ChatItem) onUpdate;

  const ProfilePanel({
    super.key,
    required this.chat,
    required this.onUpdate,
  });

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ChatItem _localChat;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _localChat = widget.chat;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          _buildHeader(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Media"),
              Tab(text: "Files"),
              Tab(text: "Voice"),
              Tab(text: "Settings"),
            ],
            indicatorColor: Colors.teal,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlaceholderTab("Media"),
                _buildPlaceholderTab("Files"),
                _buildPlaceholderTab("Voice Notes"),
                _buildSettingsTab(),
              ],
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey.shade800,
            child: Text(
              _localChat.name[0].toUpperCase(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localChat.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Online",
                  style: TextStyle(color: Colors.green.shade400, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _localChat.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _localChat.pinned ? Colors.teal : Colors.grey,
            ),
            onPressed: () {
              setState(() =>
                  _localChat = _localChat.copyWith(pinned: !_localChat.pinned));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingItem(
          "Chat Mode",
          _localChat.chatMode.label,
          Icons.settings_suggest,
          () => _showModePicker(),
        ),
        _buildSettingItem(
          "Theme",
          "Theme ${_localChat.themeIndex + 1}",
          Icons.palette,
          () => _showThemePicker(),
        ),
        _buildSettingItem(
          "Disappearing Messages",
          _localChat.disappearing.label,
          Icons.timer,
          () => _showDisappearingPicker(),
        ),
        SwitchListTile(
          title: const Text("Mute Notifications"),
          value: _localChat.muted,
          onChanged: (val) {
            setState(() => _localChat = _localChat.copyWith(muted: val));
          },
          secondary: const Icon(Icons.notifications_off),
          activeThumbColor: Colors.teal,
        ),
        const Divider(color: Colors.grey),
        SwitchListTile(
          title: const Text("Auto-clear Window"),
          subtitle: const Text(
              "Automatically delete messages outside specified window"),
          value: _localChat.autoClearEnabled,
          onChanged: (val) {
            setState(
                () => _localChat = _localChat.copyWith(autoClearEnabled: val));
          },
          secondary: const Icon(Icons.auto_delete, color: Colors.teal),
          activeThumbColor: Colors.teal,
        ),
        if (_localChat.autoClearEnabled) ...[
          _buildSettingItem(
            "Start Time",
            _localChat.autoClearStart?.format(context) ?? "Not set",
            Icons.access_time,
            () => _showTimePicker(true),
          ),
          _buildSettingItem(
            "End Time",
            _localChat.autoClearEnd?.format(context) ?? "Not set",
            Icons.access_time_filled,
            () => _showTimePicker(false),
          ),
        ],
      ],
    );
  }

  void _showTimePicker(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_localChat.autoClearStart ?? TimeOfDay.now())
          : (_localChat.autoClearEnd ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _localChat = _localChat.copyWith(autoClearStart: picked);
        } else {
          _localChat = _localChat.copyWith(autoClearEnd: picked);
        }
      });
    }
  }

  Widget _buildSettingItem(
      String title, String value, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title),
      subtitle: Text(value, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          Text("No $title found", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            widget.onUpdate(_localChat);
            Navigator.pop(context);
          },
          child: const Text("Save Changes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showModePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: ChatMode.values
            .map((mode) => ListTile(
                  leading: Icon(mode.icon),
                  title: Text(mode.label),
                  onTap: () {
                    setState(
                        () => _localChat = _localChat.copyWith(chatMode: mode));
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: List.generate(
            4,
            (index) => ListTile(
                  leading: const Icon(Icons.palette),
                  title: Text("Theme ${index + 1}"),
                  onTap: () {
                    setState(() =>
                        _localChat = _localChat.copyWith(themeIndex: index));
                    Navigator.pop(context);
                  },
                )),
      ),
    );
  }

  void _showDisappearingPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: DisappearingOption.values
            .map((opt) => ListTile(
                  leading: const Icon(Icons.timer),
                  title: Text(opt.label),
                  onTap: () {
                    setState(() =>
                        _localChat = _localChat.copyWith(disappearing: opt));
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
}
