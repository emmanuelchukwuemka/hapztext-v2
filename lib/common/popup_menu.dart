import 'package:flutter/material.dart';
import 'package:haptext_api/common/theme/custom_theme_extension.dart';

class Popup extends StatefulWidget {
  Popup({
    super.key,
    required List<PopupMenuItem> PMItem,
    this.icn = const Icon(
      Icons.more_vert,
      size: 22,
    ),
  });

  final Icon icn;

  @override
  State<Popup> createState() => _PopupState();
}

class _PopupState extends State<Popup> {
  final List<PopupMenuItem> PMItem = [];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      position: PopupMenuPosition.under,
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      color: context.theme.bgColor,
      icon: Icon(
        Icons.more_vert,
        size: 22,
        color: context.theme.primaryColor,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(0.0),
          bottomRight: Radius.circular(30),
          bottomLeft: Radius.circular(30),
        ),
      ),
      itemBuilder: (BuildContext context) => PMItem,
    );
  }
}
