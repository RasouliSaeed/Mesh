import 'package:flutter/material.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';

class MeshSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final VoidCallback? onClear;

  const MeshSearchField({
    this.controller,
    this.onChanged,
    this.hintText = 'جستجوی دستگاه یا فایل...',
    this.onClear,
    super.key,
  });

  @override
  State<MeshSearchField> createState() => _MeshSearchFieldState();
}

class _MeshSearchFieldState extends State<MeshSearchField> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_updateHasText);
  }

  void _updateHasText() {
    final has = _controller.text.isNotEmpty;
    if (has != _hasText) {
      setState(() {
        _hasText = has;
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_updateHasText);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.8),
        borderRadius: LocaraDesignTokens.borderRadiusLarge,
        border: Border.all(
          color: LocaraDesignTokens.cardBorderSubtle,
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(
          color: LocaraDesignTokens.primaryText,
          fontSize: 14,
        ),
        cursorColor: LocaraDesignTokens.cyan,
        decoration: InputDecoration(
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: LocaraDesignTokens.mutedText,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: LocaraDesignTokens.mutedText,
            size: 20,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: LocaraDesignTokens.mutedText,
                    size: 18,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                    widget.onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Legacy search field alias for backward compatibility
typedef LocaraSearchField = MeshSearchField;
