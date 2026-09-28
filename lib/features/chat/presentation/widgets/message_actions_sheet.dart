import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/message.dart';

enum MessageAction { reply, copy, edit, pin, unpin, deleteForMe, deleteForAll }

class MessageActionResult {
  const MessageActionResult({this.action, this.reaction, this.removeReaction = false});

  final MessageAction? action;
  final String? reaction;
  final bool removeReaction;
}

const kReactions = ['❤️', '😍', '😂', '😮', '🥺', '🙏', '👍'];

Future<MessageActionResult?> showMessageActions(
  BuildContext context, {
  required Message message,
  required bool isMine,
  required String? myReaction,
}) {
  final canEdit = isMine &&
      message.type == MessageType.text &&
      !message.deletedForAll &&
      DateTime.now().difference(message.createdAt) < const Duration(hours: 24);
  return showModalBottomSheet<MessageActionResult>(
    context: context,
    builder: (ctx) {
      Widget tile(IconData icon, String label, MessageAction action, {bool danger = false}) => ListTile(
            leading: Icon(icon, color: danger ? AppColors.error : null),
            title: Text(label, style: danger ? const TextStyle(color: AppColors.error) : null),
            onTap: () => Navigator.pop(ctx, MessageActionResult(action: action)),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.deletedForAll)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: ctx.palette.card,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final e in kReactions)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(
                              ctx,
                              e == myReaction
                                  ? const MessageActionResult(removeReaction: true)
                                  : MessageActionResult(reaction: e),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: e == myReaction ? AppColors.rose.withValues(alpha: 0.35) : null,
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (!message.deletedForAll) tile(Icons.reply_rounded, 'Yanıtla', MessageAction.reply),
            if ((message.text?.isNotEmpty ?? false) && !message.deletedForAll)
              tile(Icons.copy_rounded, 'Kopyala', MessageAction.copy),
            if (canEdit) tile(Icons.edit_outlined, 'Düzenle', MessageAction.edit),
            if (!message.deletedForAll)
              message.pinned
                  ? tile(Icons.push_pin_outlined, 'Sabitlemeyi kaldır', MessageAction.unpin)
                  : tile(Icons.push_pin_outlined, 'Sabitle', MessageAction.pin),
            tile(Icons.delete_outline_rounded, 'Benden sil', MessageAction.deleteForMe, danger: true),
            if (isMine && !message.deletedForAll)
              tile(Icons.delete_forever_outlined, 'Herkesten sil', MessageAction.deleteForAll, danger: true),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
