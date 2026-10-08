import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class ScanzoButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final double height;
  final bool isOutlined;
  final double borderRadius;

  const ScanzoButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor = AppColors.primaryPink,
    this.textColor = AppColors.textPrimary,
    this.height = 50,
    this.isOutlined = false,
    this.borderRadius = 14,
  });

  @override
  State<ScanzoButton> createState() => _ScanzoButtonState();
}

class _ScanzoButtonState extends State<ScanzoButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _scale = 0.97);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _scale = 1.0);
    }
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          height: widget.height,
          child: widget.isOutlined
              ? OutlinedButton(
                  onPressed: isEnabled ? widget.onPressed : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.textColor,
                    side: BorderSide(
                      color: widget.backgroundColor == AppColors.primaryPink
                          ? AppColors.primaryPinkDark
                          : widget.backgroundColor,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                  ),
                  child: _buildChild(),
                )
              : ElevatedButton(
                  onPressed: isEnabled ? widget.onPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.backgroundColor,
                    foregroundColor: widget.textColor,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                  ),
                  child: _buildChild(),
                ),
        ),
      ),
    );
  }

  Widget _buildChild() {
    if (widget.isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(widget.textColor),
        ),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 19, color: widget.textColor),
          const SizedBox(width: 8),
          Text(widget.text, style: AppTypography.buttonText.copyWith(color: widget.textColor)),
        ],
      );
    }

    return Text(widget.text, style: AppTypography.buttonText.copyWith(color: widget.textColor));
  }
}
