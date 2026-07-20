import 'package:flutter/material.dart';

import '../../core/localization/localization_extensions.dart';
import '../../core/theme/fitlog_theme.dart';
import 'food_image_picker.dart';

Future<FoodImageSource?> showFoodImageSourceSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Key cameraButtonKey,
  required Key galleryButtonKey,
}) {
  return showModalBottomSheet<FoodImageSource>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => _FoodImageSourceSheet(
      title: title,
      subtitle: subtitle,
      cameraButtonKey: cameraButtonKey,
      galleryButtonKey: galleryButtonKey,
    ),
  );
}

class _FoodImageSourceSheet extends StatelessWidget {
  const _FoodImageSourceSheet({
    required this.title,
    required this.subtitle,
    required this.cameraButtonKey,
    required this.galleryButtonKey,
  });

  final String title;
  final String subtitle;
  final Key cameraButtonKey;
  final Key galleryButtonKey;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.fitLogTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ImageSourceAction(
                    key: cameraButtonKey,
                    icon: Icons.photo_camera_outlined,
                    label: strings.takePhoto,
                    onTap: () =>
                        Navigator.of(context).pop(FoodImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageSourceAction(
                    key: galleryButtonKey,
                    icon: Icons.photo_library_outlined,
                    label: strings.chooseFromGallery,
                    onTap: () =>
                        Navigator.of(context).pop(FoodImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSourceAction extends StatelessWidget {
  const _ImageSourceAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Material(
      color: fitTheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: fitTheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 112,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 30, color: fitTheme.primaryBright),
              const SizedBox(height: 10),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
