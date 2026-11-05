import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../validation/password_reset_validators.dart';

/// A native editor under six visual boxes preserves keyboard editing,
/// long-press paste, selection, backspace and one-time-code autofill.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({super.key, required this.controller, this.onSubmitted});
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Doğrulama kodu',
    child: Stack(
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          validator: PasswordResetValidators.code,
          onFieldSubmitted: widget.onSubmitted,
          showCursor: false,
          style: const TextStyle(color: Colors.transparent, fontSize: 24),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            fillColor: Colors.transparent,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: Listenable.merge([widget.controller, _focus]),
                builder: (context, _) {
                  final colors = Theme.of(context).colorScheme;
                  final text = widget.controller.text;
                  final offset = widget.controller.selection.extentOffset.clamp(
                    0,
                    5,
                  );
                  return Row(
                    children: List.generate(
                      6,
                      (index) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _focus.hasFocus && offset == index
                                        ? colors.secondary
                                        : colors.outlineVariant,
                              ),
                            ),
                            child: Text(
                              index < text.length ? text[index] : '',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
