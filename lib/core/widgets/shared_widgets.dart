import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── App Constants ────────────────────────────────────────────────────────────

class AppConstants {
  static const double horizontalPadding = 20.0;
  static const double borderRadius = 12.0;
}

// ─── Spendly Button ───────────────────────────────────────────────────────────

class SpendlyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color? color;

  const SpendlyButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onButtonColor = color != null ? Colors.white : cs.onPrimary;

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? cs.primary,
        foregroundColor: onButtonColor,
        minimumSize: Size(isFullWidth ? double.infinity : 0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: onButtonColor, strokeWidth: 2),
            )
          : Text(
              text,
              style: TextStyle(
                color: onButtonColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );

    return isFullWidth ? button : IntrinsicWidth(child: button);
  }
}

// ─── Spendly Text Field ───────────────────────────────────────────────────────

class SpendlyTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  const SpendlyTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}

// ─── Spendly Card ─────────────────────────────────────────────────────────────

class SpendlyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final Gradient? gradient;

  const SpendlyCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final resolvedBackground = backgroundColor ??
        theme.cardTheme.color ??
        cs.surfaceContainerHighest;

    final decoration = BoxDecoration(
      color: gradient != null ? null : resolvedBackground,
      gradient: gradient,
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      border: gradient == null
          ? Border.all(
              color: isDark
                  ? cs.outline.withAlpha(120)
                  : cs.outlineVariant.withAlpha(180),
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withAlpha(70)
              : theme.shadowColor.withAlpha(10),
          blurRadius: isDark ? 18 : 10,
          offset: const Offset(0, 6),
        ),
      ],
    );

    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        child: card,
      );
    }
    return card;
  }
}

// ─── User Avatar ──────────────────────────────────────────────────────────────

class UserAvatar extends StatelessWidget {
  final String name;
  final String userId;
  final double size;
  final bool isVerified;
  final String? avatarUrl;

  const UserAvatar({
    super.key,
    required this.name,
    required this.userId,
    this.size = 36,
    this.isVerified = false,
    this.avatarUrl,
  });

  Color _colorFromId(String id) {
    final List<Color> colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEF4444), // Red
    ];
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = id.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  ImageProvider? _avatarImage() {
    final source = avatarUrl;
    if (source == null || source.isEmpty) return null;
    if (_isInlineImage(source)) {
      final bytes = _tryDecodeInlineImage(source);
      return bytes == null ? null : MemoryImage(bytes);
    }
    return NetworkImage(source);
  }

  bool _isInlineImage(String value) => value.startsWith('data:image/');

  Uint8List _decodeInlineImage(String value) {
    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return Uint8List(0);
    return base64Decode(value.substring(commaIndex + 1));
  }

  Uint8List? _tryDecodeInlineImage(String value) {
    try {
      final bytes = _decodeInlineImage(value);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Builder(builder: (context) {
          final image = _avatarImage();
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: image == null ? _colorFromId(userId) : Colors.transparent,
              shape: BoxShape.circle,
              image: image != null
                  ? DecorationImage(
                      image: image,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: image == null
                ? Center(
                    child: Text(
                      _initials(name),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          );
        }),
        if (isVerified)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: size * 0.35,
              ),
            ),
          ),
      ],
    );
  }
}

class SpendlyImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SpendlyImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  bool _isRemote(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool _isInlineImage(String value) => value.startsWith('data:image/');

  Uint8List _decodeInlineImage(String value) {
    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return Uint8List(0);
    return base64Decode(value.substring(commaIndex + 1));
  }

  Uint8List? _tryDecodeInlineImage(String value) {
    try {
      final bytes = _decodeInlineImage(value);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inlineBytes = _isInlineImage(source)
        ? _tryDecodeInlineImage(source)
        : null;
    final image = _isRemote(source)
        ? Image.network(
            source,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _fallback(context),
          )
        : inlineBytes != null
            ? Image.memory(
                inlineBytes,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (context, error, stackTrace) =>
                    _fallback(context),
              )
            : _fallback(context);

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  static StatusBadge pending({String label = 'Pending'}) => StatusBadge(
        label: label,
        color: SpendlyColors.warning,
        backgroundColor: SpendlyColors.warning.withAlpha(28),
      );

  static StatusBadge verified({String label = 'Verified'}) => StatusBadge(
        label: label,
        color: SpendlyColors.success,
        backgroundColor: SpendlyColors.success.withAlpha(28),
      );

  static StatusBadge rejected({String label = 'Rejected'}) => StatusBadge(
        label: label,
        color: SpendlyColors.danger,
        backgroundColor: SpendlyColors.danger.withAlpha(28),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Gradient? gradient;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return SpendlyCard(
      padding: const EdgeInsets.all(16),
      gradient: gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: gradient != null ? Colors.white24 : color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: gradient != null ? Colors.white : color,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: gradient != null
                      ? Colors.white70
                      : SpendlyColors.neutral500,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: gradient != null ? Colors.white : color,
                  ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: gradient != null
                    ? Colors.white60
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const Spacer(),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              SpendlyButton(
                text: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Spendly Category Chip Grid ───────────────────────────────────────────────

class SpendlyCategoryChipGrid<T> extends StatelessWidget {
  final List<T> items;
  final T selected;
  final String Function(T) label;
  final void Function(T) onSelect;

  const SpendlyCategoryChipGrid({
    super.key,
    required this.items,
    required this.selected,
    required this.label,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item == selected;
        final labelStr = label(item);
        final emoji = labelStr.contains(' ') ? labelStr.split(' ').first : '';
        final text = labelStr.contains(' ')
            ? labelStr.split(' ').skip(1).join(' ')
            : labelStr;

        return GestureDetector(
          onTap: () => onSelect(item),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: emoji.isNotEmpty
                          ? Text(emoji, style: const TextStyle(fontSize: 22))
                          : const Icon(Icons.category_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Spendly Filter Chip Row ──────────────────────────────────────────────────

class SpendlyFilterChipRow<T> extends StatelessWidget {
  final List<T> items;
  final T? selected;
  final String Function(T) label;
  final void Function(T) onSelect;
  final double height;

  const SpendlyFilterChipRow({
    super.key,
    required this.items,
    this.selected,
    required this.label,
    required this.onSelect,
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label(item)),
              selected: isSelected,
              onSelected: (_) => onSelect(item),
              backgroundColor: Colors.white,
              selectedColor: SpendlyColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : SpendlyColors.neutral700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? SpendlyColors.primary : SpendlyColors.neutral200,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }
}
