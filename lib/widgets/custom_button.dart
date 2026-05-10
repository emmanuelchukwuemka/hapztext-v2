import 'package:haptext_api/exports.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
// import 'package:haptext_api/exports.dart';

class Appbutton extends StatelessWidget {
  const Appbutton(
      {super.key,
      this.buttonColor,
      this.child,
      this.label,
      this.onTap,
      this.width,
      this.height,
      this.labelColor,
      this.isLoading = false,
      this.gradient = false,
      this.borderColor,
      this.border,
      this.labelSize,
      this.labelWeight});

  final Color? buttonColor, borderColor, labelColor;
  final Widget? child;
  final String? label;
  final Function()? onTap;
  final double? width, height, labelSize;
  final bool isLoading, gradient;
  final bool? border;
  final FontWeight? labelWeight;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final primaryGradient =
        const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? size.width,
        height: height ?? 54,
        decoration: BoxDecoration(
          color:
              gradient ? null : (buttonColor ?? Theme.of(context).primaryColor),
          gradient: gradient ? primaryGradient : null,
          borderRadius: BorderRadius.circular(12),
          border: (border ?? false)
              ? Border.all(color: borderColor ?? Colors.transparent)
              : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? LoadingAnimationWidget.beat(color: Colors.white, size: 24)
            : child ??
                AppText(
                    text: label ?? '',
                    color: labelColor ?? Colors.white,
                    fontSize: labelSize ?? 16,
                    fontWeight: labelWeight ?? FontWeight.bold),
      ),
    );
  }
}
