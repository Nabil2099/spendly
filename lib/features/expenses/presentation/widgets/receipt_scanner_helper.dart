import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ai_advisor/data/gemini_chat_service.dart';

/// Prompts the user for Camera or Gallery, then extracts an expense draft via Gemini.
Future<ParsedExpenseDraft?> pickAndScanReceipt(
  BuildContext context, {
  VoidCallback? onParsingStarted,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.primaryGreen,
            ),
            title: const Text('Take a photo of receipt'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_library_rounded,
              color: AppColors.slateBlue,
            ),
            title: const Text('Choose receipt from gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return null;

  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 85,
  );
  if (file == null) return null;

  onParsingStarted?.call();
  final bytes = await file.readAsBytes();
  final mime = file.path.toLowerCase().endsWith('.png')
      ? 'image/png'
      : 'image/jpeg';

  return getIt<GeminiChatService>().parseExpenseFromReceipt(
    bytes,
    mimeType: mime,
  );
}

