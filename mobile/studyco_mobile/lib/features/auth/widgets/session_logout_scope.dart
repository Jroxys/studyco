import 'package:flutter/material.dart';

/// The composition root owns session cleanup and replacing protected routes.
class SessionLogoutScope extends InheritedWidget {
  const SessionLogoutScope({
    super.key,
    required this.userId,
    required this.endSession,
    required super.child,
  });

  final String? userId;
  final Future<void> Function() endSession;

  static Future<void> Function()? forUser(
    BuildContext context,
    String? userId,
  ) {
    if (userId == null || userId.trim().isEmpty) return null;
    final scope =
        context.dependOnInheritedWidgetOfExactType<SessionLogoutScope>();
    return scope?.userId == userId ? scope?.endSession : null;
  }

  static Future<void> confirm(
    BuildContext context, {
    required Future<void> Function()? endSession,
  }) async {
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => PopScope(
                  canPop: !busy,
                  child: AlertDialog(
                    scrollable: true,
                    title: const Text('Çıkış Yap'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hesabından çıkış yapmak istediğine emin misin?',
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Semantics(liveRegion: true, child: Text(error!)),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed:
                            busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('Vazgeç'),
                      ),
                      FilledButton(
                        onPressed:
                            busy
                                ? null
                                : () async {
                                  if (busy) return;
                                  if (endSession == null) {
                                    setState(
                                      () =>
                                          error =
                                              'Çıkış işlemi şu anda kullanılamıyor.',
                                    );
                                    return;
                                  }
                                  setState(() {
                                    busy = true;
                                    error = null;
                                  });
                                  try {
                                    await endSession();
                                    if (context.mounted &&
                                        ModalRoute.of(context)?.isCurrent ==
                                            true) {
                                      Navigator.of(context).pop();
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      setState(() {
                                        busy = false;
                                        error =
                                            'Çıkış yapılamadı. Tekrar deneyebilirsin.';
                                      });
                                    }
                                  }
                                },
                        child:
                            busy
                                ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel: 'Çıkış yapılıyor',
                                  ),
                                )
                                : const Text('Çıkış Yap'),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  bool updateShouldNotify(SessionLogoutScope oldWidget) =>
      oldWidget.userId != userId || oldWidget.endSession != endSession;
}
