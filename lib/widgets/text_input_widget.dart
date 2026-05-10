import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptext_api/widgets/app_text.dart';

class InputField extends StatefulWidget {
  const InputField(
      {super.key,
      this.title,
      this.hintText,
      this.suffix,
      this.prefix,
      this.onTap,
      this.isReadOnly = false,
      this.controller,
      this.verticalSpace,
      this.contentPadding,
      this.keyboardType,
      this.validator,
      this.inputFormatters,
      this.onChanged,
      this.isPassword = false,
      this.isFilled = false,
      this.fillColor,
      this.hintTextColor,
      this.hintFontSize,
      this.onEditingComplete,
      this.enabled = true,
      this.maxLines});

  final String? title;
  final String? hintText;
  final Widget? suffix;
  final Widget? prefix;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool isReadOnly;
  final TextEditingController? controller;
  final EdgeInsets? contentPadding;
  final double? verticalSpace;
  final String? Function(String?)? validator;
  final void Function(String?)? onChanged;
  final bool isPassword;
  final bool isFilled;
  final int? maxLines;
  final Color? fillColor;
  final Color? hintTextColor;
  final double? hintFontSize;
  final void Function()? onEditingComplete;
  final bool enabled;

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  bool hidePassword = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          AppText(
              text: widget.title!,
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          const SizedBox(height: 8),
        ],
        TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.sentences,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          maxLines: widget.maxLines ?? 1,
          cursorColor: Colors.white,
          onTap: widget.onTap,
          onEditingComplete: widget.onEditingComplete,
          obscureText: hidePassword && widget.isPassword,
          onChanged: widget.onChanged,
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          readOnly: widget.isReadOnly,
          validator: widget.validator,
          style: GoogleFonts.roboto(
              fontWeight: FontWeight.w400, color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hintText,
            fillColor: widget.fillColor ?? Colors.white.withOpacity(0.05),
            filled: true,
            hintStyle: GoogleFonts.roboto(
                fontWeight: FontWeight.w400,
                color: Colors.white24,
                fontSize: 14),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            errorStyle: GoogleFonts.roboto(
                fontWeight: FontWeight.w400,
                color: Colors.redAccent,
                fontSize: 12),
            prefixIcon: widget.prefix,
            border: _border,
            enabledBorder: _border,
            focusedBorder: _focusborder,
            errorBorder: _errorborder,
            focusedErrorBorder: _errorborder,
            suffixIcon: widget.isPassword
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                      log("$hidePassword");
                    },
                    child: Icon(
                        hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white38,
                        size: 20),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }

  OutlineInputBorder get _border {
    return OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12));
  }

  OutlineInputBorder get _focusborder {
    return OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF8B5CF6)), // primaryStart
        borderRadius: BorderRadius.circular(12));
  }

  OutlineInputBorder get _errorborder {
    return OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(12));
  }
}
