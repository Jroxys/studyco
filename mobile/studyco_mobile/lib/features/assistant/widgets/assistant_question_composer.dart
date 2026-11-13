import 'package:flutter/material.dart';

class AssistantQuestionComposer extends StatelessWidget {
  const AssistantQuestionComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onChanged,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool enabled, sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('assistant-draft'),
            controller: controller,
            enabled: enabled,
            readOnly: sending,
            minLines: 1,
            maxLines: 2,
            textInputAction: TextInputAction.send,
            decoration: const InputDecoration(
              hintText: 'Sorunu buraya yaz...',
              contentPadding: EdgeInsets.all(10),
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          key: const ValueKey('assistant-send'),
          tooltip: 'Soruyu gönder',
          onPressed:
              !enabled || sending || controller.text.trim().isEmpty
                  ? null
                  : onSend,
          icon:
              sending
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Yanıt bekleniyor',
                    ),
                  )
                  : const Icon(Icons.send),
        ),
      ],
    ),
  );
}
