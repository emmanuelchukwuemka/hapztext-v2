import 'dart:io';
import 'package:flutter/material.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';
import 'package:haptext_api/exports.dart';
import 'package:image_picker/image_picker.dart';

class PicsChange extends StatefulWidget {
  const PicsChange(
      {super.key,
      required this.onchangeProfile,
      required this.onchangeCoverPhoto,
      this.currentProfileUrl,
      this.currentCoverUrl});
  final Function(File profile) onchangeProfile, onchangeCoverPhoto;
  final String? currentProfileUrl;
  final String? currentCoverUrl;
  @override
  State<PicsChange> createState() => _PicsChangeState();
}

class _PicsChangeState extends State<PicsChange> {
  String? selectedBgImage;
  String? selectedProfileImage;
  showOptionsDialog(BuildContext context, bool isProfile) {
    return showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: context.theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: AppText(
          text: isProfile ? 'Change Profile Photo' : 'Change Cover Photo',
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              final ImagePicker picker = ImagePicker();
              final XFile? image =
                  await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                if (isProfile) {
                  widget.onchangeProfile(File(image.path));
                  setState(() => selectedProfileImage = image.path);
                } else {
                  widget.onchangeCoverPhoto(File(image.path));
                  setState(() => selectedBgImage = image.path);
                }
              }
            },
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF8B5CF6)),
                const SizedBox(width: 12),
                AppText(
                  text: 'Choose from Gallery',
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: Row(
              children: [
                const Icon(Icons.close, color: Colors.white38),
                const SizedBox(width: 12),
                AppText(
                  text: 'Cancel',
                  color: Colors.white38,
                  fontSize: 15,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner Area
          GestureDetector(
            onTap: () => showOptionsDialog(context, false),
            child: Container(
              height: size.height * 0.16,
              width: size.width,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                image: selectedBgImage != null
                    ? DecorationImage(
                        image: FileImage(File(selectedBgImage!)),
                        fit: BoxFit.cover)
                    : (widget.currentCoverUrl?.isNotEmpty == true)
                        ? DecorationImage(
                            image: NetworkImage(widget.currentCoverUrl!),
                            fit: BoxFit.cover)
                        : const DecorationImage(
                            image: AssetImage("assets/images/hapz_logo.png"),
                            fit: BoxFit.cover),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: const Center(
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: Icon(Icons.camera_alt, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          // Profile Pic overlapping
          Positioned(
            bottom: -30,
            left: 20,
            child: GestureDetector(
              onTap: () => showOptionsDialog(context, true),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: context.theme.bgColor!, width: 4),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: ClipOval(
                      child: selectedProfileImage != null
                          ? Image.file(File(selectedProfileImage!),
                              fit: BoxFit.cover)
                          : AppNetwokImage(
                              height: 90,
                              width: 90,
                              imageUrl: widget.currentProfileUrl ?? "",
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B5CF6),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 16),
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
}
