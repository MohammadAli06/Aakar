import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/commerce_repository.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';

String bilingual(BuildContext context, String en, String hi) =>
    context.isHindi ? hi : en;

class CraftCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  const CraftCard(
      {super.key,
      required this.child,
      this.color,
      this.padding = const EdgeInsets.all(18)});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
      decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E6DF)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x060E3026), blurRadius: 14, offset: Offset(0, 4))
          ]),
      child: Material(type: MaterialType.transparency, child: child));
}

class CraftButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  const CraftButton(this.label,
      {super.key, this.onPressed, this.icon, this.secondary = false});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SizedBox(
          width: double.infinity,
          child: secondary
              ? OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: Text(label, textAlign: TextAlign.center))
              : FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: const Color(0xFF285448),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8)
                    ],
                    Flexible(child: Text(label, textAlign: TextAlign.center))
                  ]))));
}

class StatusPill extends StatelessWidget {
  final String text;
  final bool warning;
  const StatusPill(this.text, {super.key, this.warning = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: warning ? const Color(0xFFF8EBDD) : const Color(0xFFE6F1E8),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text.replaceAll('_', ' '),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: warning
                  ? const Color(0xFF925F33)
                  : const Color(0xFF286047))));
}

class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const DetailRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF72766E)))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF28362D))))
      ]));
}

class CraftHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const CraftHeading(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: Color(0xFF233C32),
                height: 1.3)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF73796F), height: 1.6))
        ]
      ]));
}

/// Offline artwork: woven lines and clay forms, rather than misleading stock photos.
class CraftImage extends ConsumerWidget {
  final String source;
  final double size;
  const CraftImage(this.source, {super.key, this.size = 80});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(commerceProvider);
    final fallback =
        CustomPaint(painter: _CraftPainter(source), size: Size.square(size));
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
            width: size,
            height: size,
            child: source.startsWith('/') || source.contains(':\\')
                ? Image.file(File(source),
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
                : source.startsWith('http')
                    ? Image.network(source,
                        headers: repo.connected &&
                                source.startsWith(
                                    '${repo.endpoint}/api/v1/workspace/media/')
                            ? {'Authorization': 'Bearer ${repo.token}'}
                            : null,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback)
                    : fallback));
  }
}

class _CraftPainter extends CustomPainter {
  final String kind;
  _CraftPainter(this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFFF0E6D7), Color(0xFFDDD3C1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              .createShader(const Rect.fromLTWH(0, 0, 100, 100)));
    canvas.drawOval(
        const Rect.fromLTWH(13, 79, 75, 11),
        Paint()
          ..color = const Color(0x22000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final pottery = kind.contains('pot') || kind.contains('clay');
    final tote = kind.contains('tote');
    final path = Path();
    if (pottery) {
      path.moveTo(35, 22);
      path.cubicTo(40, 35, 12, 47, 22, 71);
      path.quadraticBezierTo(25, 88, 50, 86);
      path.quadraticBezierTo(77, 88, 79, 69);
      path.cubicTo(87, 46, 60, 35, 65, 22);
      path.close();
    } else {
      path.moveTo(18, tote ? 35 : 40);
      path.lineTo(82, tote ? 35 : 40);
      path.lineTo(75, 83);
      path.quadraticBezierTo(50, 89, 25, 83);
      path.close();
    }
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
                  colors: pottery
                      ? [
                          const Color(0xFFBB7E4F),
                          const Color(0xFF8E5132),
                          const Color(0xFFD39B6D)
                        ]
                      : tote
                          ? [
                              const Color(0xFF6B8790),
                              const Color(0xFF3C5A64),
                              const Color(0xFF8DA8A6)
                            ]
                          : [
                              const Color(0xFFD7AE6C),
                              const Color(0xFFAA7E43),
                              const Color(0xFFE0BE82)
                            ])
              .createShader(const Rect.fromLTWH(15, 20, 70, 68)));
    canvas.save();
    canvas.clipPath(path);
    for (var y = 29.0; y < 88; y += pottery ? 10 : 4) {
      canvas.drawLine(
          Offset(10, y),
          Offset(90, y + 2),
          Paint()
            ..color = const Color(0x55754B29)
            ..strokeWidth = 1);
      if (!pottery)
        for (var x = 20.0; x < 85; x += 7) {
          canvas.drawLine(
              Offset(x, y),
              Offset(x + 3, y + 4),
              Paint()
                ..color = const Color(0x66FFF2C5)
                ..strokeWidth = 1.2);
        }
    }
    canvas.restore();
    if (pottery) {
      canvas.drawOval(const Rect.fromLTWH(34, 18, 32, 10),
          Paint()..color = const Color(0xFF77482E));
      canvas.drawOval(const Rect.fromLTWH(38, 20, 24, 5),
          Paint()..color = const Color(0xFF392E22));
    } else if (tote) {
      canvas.drawArc(
          const Rect.fromLTWH(32, 12, 36, 49),
          pi,
          pi,
          false,
          Paint()
            ..color = const Color(0xFF28484E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5);
    } else {
      canvas.drawOval(const Rect.fromLTWH(16, 31, 68, 16),
          Paint()..color = const Color(0xFFC69B5D));
      canvas.drawOval(const Rect.fromLTWH(22, 34, 56, 10),
          Paint()..color = const Color(0xFF795431));
      canvas.drawArc(
          const Rect.fromLTWH(29, 10, 42, 52),
          pi,
          pi,
          false,
          Paint()
            ..color = const Color(0xFFA4773D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
    }
  }

  @override
  bool shouldRepaint(covariant _CraftPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

class EmptyCraft extends StatelessWidget {
  final String title;
  final String message;
  final Widget? action;
  const EmptyCraft(this.title, this.message, {super.key, this.action});
  @override
  Widget build(BuildContext context) => CraftCard(
          child: Column(children: [
        const SizedBox(height: 22),
        const Icon(Icons.spa_outlined, size: 42, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        if (action != null) action!,
        const SizedBox(height: 22)
      ]));
}
