import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/localization_extensions.dart';
import '../../core/widgets/fitlog_bottom_nav_bar.dart';
import '../../core/widgets/fitlog_notifications.dart';
import '../../domain/models/ai_availability.dart';
import '../../domain/models/subscription_status.dart';
import '../account/account_controller.dart';

enum AiShellMode { disabled, ready, processing, needsClarification }

enum _AiProvider { chatGpt, qwen }

class AiPage extends StatefulWidget {
  const AiPage({super.key, this.mode, this.displayName});

  final AiShellMode? mode;
  final String? displayName;

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController _controller = TextEditingController();
  _AiProvider _provider = _AiProvider.chatGpt;
  bool _historyOpen = false;
  String? _accountBoundaryKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountController = _maybeAccountController(listen: true);
    _syncAccountDraftBoundary(accountController);
    final effectiveMode = _effectiveMode(accountController);
    final cloudNickname =
        accountController?.cloudProfileState.cloudProfile?.profile.nickname;
    final canSend = widget.mode == null
        ? accountController?.aiAvailability.canSend ?? false
        : effectiveMode != AiShellMode.disabled;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final keyboardVisible = bottomInset > 0;
    final centerBottomPadding = keyboardVisible
        ? math.min(bottomInset + 190.0, mediaQuery.size.height * 0.64)
        : 148.0;
    final composerBottomPadding = keyboardVisible
        ? bottomInset + 12.0
        : FitLogBottomNavBar.floatingControlScreenBottomPaddingFor(context);

    return Stack(
      key: const ValueKey<String>('ai_page'),
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: _AiAnimatedBackground(
              mode: effectiveMode,
              pausedForKeyboard: keyboardVisible,
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, centerBottomPadding),
                  child: Center(
                    child: _AiCenterStatus(
                      mode: effectiveMode,
                      displayName:
                          widget.displayName ??
                          cloudNickname ??
                          accountController?.authSession.displayName,
                    ),
                  ),
                ),
              ),
              _AiTopBar(
                accountController: accountController,
                onOpenHistory: () => setState(() => _historyOpen = true),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    composerBottomPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: _AiComposer(
                      controller: _controller,
                      provider: _provider,
                      canSend: canSend,
                      mode: effectiveMode,
                      statusLabel: _statusLabel(context, accountController),
                      onProviderChanged: (provider) {
                        setState(() => _provider = provider);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_historyOpen)
          _AiHistoryPanel(onClose: () => setState(() => _historyOpen = false)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: math.max(mediaQuery.padding.bottom, 8),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  AccountController? _maybeAccountController({required bool listen}) {
    try {
      return Provider.of<AccountController>(context, listen: listen);
    } catch (_) {
      return null;
    }
  }

  AiShellMode _effectiveMode(AccountController? accountController) {
    final explicitMode = widget.mode;
    if (explicitMode != null) {
      return explicitMode;
    }
    return accountController?.aiAvailability.isReadyVisual == true
        ? AiShellMode.ready
        : AiShellMode.disabled;
  }

  String _statusLabel(
    BuildContext context,
    AccountController? accountController,
  ) {
    final strings = context.strings;
    final availability = accountController?.aiAvailability;
    if (availability == null) {
      return strings.aiSignedOutStatus;
    }
    switch (availability.status) {
      case AiAvailabilityStatus.signedOut:
        return strings.aiSignedOutStatus;
      case AiAvailabilityStatus.offline:
        return strings.aiOfflineStatus;
      case AiAvailabilityStatus.subscriptionInactive:
        if (accountController?.subscriptionStatus.state ==
            SubscriptionState.error) {
          return strings.subscriptionUnavailable;
        }
        return strings.subscriptionInactive;
      case AiAvailabilityStatus.profileMissing:
        return strings.profileRequired;
      case AiAvailabilityStatus.readyForPhase3:
        return strings.aiAvailableStatus;
    }
  }

  void _syncAccountDraftBoundary(AccountController? accountController) {
    final nextKey =
        '${accountController?.authSession.accountId ?? 'signed_out'}:${accountController?.accountChangeEpoch ?? 0}';
    final previousKey = _accountBoundaryKey;
    _accountBoundaryKey = nextKey;
    if (previousKey != null && previousKey != nextKey) {
      _controller.clear();
    }
  }
}

class _AiAnimatedBackground extends StatefulWidget {
  const _AiAnimatedBackground({
    required this.mode,
    required this.pausedForKeyboard,
  });

  final AiShellMode mode;
  final bool pausedForKeyboard;

  @override
  State<_AiAnimatedBackground> createState() => _AiAnimatedBackgroundState();
}

class _AiAnimatedBackgroundState extends State<_AiAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AiAnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _duration;
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration get _duration {
    switch (widget.mode) {
      case AiShellMode.processing:
        return const Duration(seconds: 10);
      case AiShellMode.ready:
      case AiShellMode.needsClarification:
        return const Duration(seconds: 16);
      case AiShellMode.disabled:
        return const Duration(seconds: 36);
    }
  }

  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = !widget.pausedForKeyboard && !reduceMotion;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _AiFlowBackgroundPainter(
            progress: _controller.value,
            mode: widget.mode,
          ),
        );
      },
    );
  }
}

class _AiFlowBackgroundPainter extends CustomPainter {
  const _AiFlowBackgroundPainter({required this.progress, required this.mode});

  final double progress;
  final AiShellMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final disabled = mode == AiShellMode.disabled;
    final emphasis = switch (mode) {
      AiShellMode.processing => 1.0,
      AiShellMode.ready => 0.42,
      AiShellMode.needsClarification => 0.24,
      AiShellMode.disabled => 0.0,
    };
    final shift = math.sin(progress * math.pi * 2);

    final baseColors = disabled
        ? const <Color>[Color(0xFFF5F4F1), Color(0xFFE7ECE6), Color(0xFFF0F3EE)]
        : const <Color>[
            Color(0xFFF5CDD9),
            Color(0xFFD8F2E4),
            Color(0xFFA8DDF6),
          ];

    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-0.64 + shift * 0.14, -1),
        end: Alignment(0.76 - shift * 0.14, 1),
        colors: baseColors,
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final washPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + shift * 0.20, -0.4),
        end: Alignment(1, 0.8),
        colors: disabled
            ? <Color>[
                Colors.white.withValues(alpha: 0.16),
                const Color(0xFFDDE8DD).withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.16),
              ]
            : <Color>[
                const Color(
                  0xFFFFF5DF,
                ).withValues(alpha: 0.30 + emphasis * 0.10),
                const Color(
                  0xFFA9E7D3,
                ).withValues(alpha: 0.34 + emphasis * 0.12),
                const Color(
                  0xFFC3E5FF,
                ).withValues(alpha: 0.30 + emphasis * 0.10),
              ],
      ).createShader(rect);

    final washPath = Path()
      ..moveTo(-size.width * 0.18, size.height * (0.15 + shift * 0.03))
      ..cubicTo(
        size.width * 0.28,
        size.height * (0.02 - shift * 0.04),
        size.width * 0.70,
        size.height * (0.34 + shift * 0.05),
        size.width * 1.16,
        size.height * (0.20 - shift * 0.02),
      )
      ..lineTo(size.width * 1.16, size.height * 0.80)
      ..cubicTo(
        size.width * 0.70,
        size.height * (0.68 + shift * 0.04),
        size.width * 0.26,
        size.height * (0.90 - shift * 0.03),
        -size.width * 0.18,
        size.height * (0.72 + shift * 0.02),
      )
      ..close();
    canvas.drawPath(washPath, washPaint);

    final veilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: disabled ? 0.18 : 0.12),
          Colors.white.withValues(alpha: disabled ? 0.24 : 0.10),
          Colors.white.withValues(alpha: disabled ? 0.05 : 0.00),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, veilPaint);
  }

  @override
  bool shouldRepaint(covariant _AiFlowBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.mode != mode;
  }
}

class _AiTopBar extends StatelessWidget {
  const _AiTopBar({
    required this.onOpenHistory,
    required this.accountController,
  });

  final VoidCallback onOpenHistory;
  final AccountController? accountController;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: <Widget>[
          _AiRoundButton(
            tooltip: strings.aiHistoryTooltip,
            icon: Icons.history_rounded,
            onPressed: onOpenHistory,
          ),
          const Spacer(),
          _AiRoundButton(
            tooltip: strings.aiAccountTooltip,
            icon: Icons.manage_accounts_outlined,
            onPressed: () {
              if (accountController == null) {
                FitLogNotifications.info(context, strings.aiAccountComingSoon);
                return;
              }
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) {
                  return AnimatedBuilder(
                    animation: accountController!,
                    builder: (context, _) {
                      return _AiAccountStatusSheet(
                        accountController: accountController!,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiRoundButton extends StatelessWidget {
  const _AiRoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.70),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: const Color(0xFF506052)),
          ),
        ),
      ),
    );
  }
}

class _AiCenterStatus extends StatelessWidget {
  const _AiCenterStatus({required this.mode, required this.displayName});

  final AiShellMode mode;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final name = displayName?.trim();

    if (mode == AiShellMode.disabled) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            strings.aiSignInRequired,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF172018),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.aiDisabledBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF647067),
              height: 1.4,
            ),
          ),
        ],
      );
    }

    final listening = strings.aiListening;
    final hasName = name != null && name.isNotEmpty;

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: listening),
          if (hasName) TextSpan(text: strings.aiListeningNameSeparator),
          if (hasName)
            TextSpan(
              text: name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w500,
        color: const Color(0xFF111C16),
        letterSpacing: 0,
      ),
    );
  }
}

class _AiComposer extends StatelessWidget {
  const _AiComposer({
    required this.controller,
    required this.provider,
    required this.canSend,
    required this.mode,
    required this.statusLabel,
    required this.onProviderChanged,
  });

  final TextEditingController controller;
  final _AiProvider provider;
  final bool canSend;
  final AiShellMode mode;
  final String statusLabel;
  final ValueChanged<_AiProvider> onProviderChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _AiProviderSelector(
              provider: provider,
              onChanged: onProviderChanged,
            ),
            _AiStatusPill(label: statusLabel),
          ],
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF273321).withValues(alpha: 0.08),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Tooltip(
                  message: strings.aiAttachTooltip,
                  child: IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.add_rounded),
                    color: const Color(0xFF506052),
                    disabledColor: const Color(0xFF9DA89F),
                  ),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 112),
                    child: TextField(
                      key: const ValueKey<String>('ai_composer_field'),
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: strings.aiComposerHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: strings.aiSendTooltip,
                  child: IconButton.filled(
                    key: const ValueKey<String>('ai_send_button'),
                    onPressed: canSend ? () {} : null,
                    style: IconButton.styleFrom(
                      disabledBackgroundColor: const Color(0xFFD8E0D7),
                      disabledForegroundColor: const Color(0xFF8C978D),
                      backgroundColor: const Color(0xFF5FA94D),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AiAccountStatusSheet extends StatelessWidget {
  const _AiAccountStatusSheet({required this.accountController});

  final AccountController accountController;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final auth = accountController.authSession;
    final subscription = accountController.subscriptionStatus;
    final isSignedIn = auth.isSignedIn;
    final localContextAllowed =
        accountController.localContextPermission?.allowed ?? false;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.aiAccountTooltip,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _AiAccountLine(
              icon: Icons.person_outline_rounded,
              label: isSignedIn
                  ? auth.email ?? auth.accountId ?? strings.aiAvailableStatus
                  : strings.aiSignedOutStatus,
            ),
            const SizedBox(height: 8),
            _AiAccountLine(
              icon: Icons.verified_user_outlined,
              label: subscription.isActive
                  ? strings.subscriptionActive
                  : subscription.state == SubscriptionState.error
                  ? strings.subscriptionUnavailable
                  : strings.subscriptionInactive,
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              key: const ValueKey<String>('ai_local_context_permission_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.aiLocalContextPermissionTitle),
              subtitle: Text(strings.aiLocalContextPermissionBody),
              value: localContextAllowed,
              onChanged: isSignedIn
                  ? (allowed) async {
                      try {
                        await accountController.setLocalContextAllowed(allowed);
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }
                        FitLogNotifications.error(
                          context,
                          strings.phase2ErrorMessage(
                            'local_context_save_failed',
                          ),
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            if (!accountController.backendConfigured)
              Text(
                strings.phase2BackendNotConfigured,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF8A6A20),
                  height: 1.35,
                ),
              ),
            if (isSignedIn) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  accountController.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(strings.signOut),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              strings.phase3Required,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF687568)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiAccountLine extends StatelessWidget {
  const _AiAccountLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: const Color(0xFF4F6250)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AiProviderSelector extends StatelessWidget {
  const _AiProviderSelector({required this.provider, required this.onChanged});

  final _AiProvider provider;
  final ValueChanged<_AiProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _AiProviderChip(
            key: const ValueKey<String>('ai_provider_chatgpt'),
            label: strings.aiProviderChatGpt,
            selected: provider == _AiProvider.chatGpt,
            onTap: () => onChanged(_AiProvider.chatGpt),
          ),
          _AiProviderChip(
            key: const ValueKey<String>('ai_provider_qwen'),
            label: strings.aiProviderQwen,
            selected: provider == _AiProvider.qwen,
            onTap: () => onChanged(_AiProvider.qwen),
          ),
        ],
      ),
    );
  }
}

class _AiProviderChip extends StatelessWidget {
  const _AiProviderChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.86) : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected
                  ? const Color(0xFF284A31)
                  : const Color(0xFF66736B),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AiStatusPill extends StatelessWidget {
  const _AiStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.radio_button_unchecked_rounded,
              size: 12,
              color: Color(0xFF7E8A83),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF66736B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiHistoryPanel extends StatelessWidget {
  const _AiHistoryPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final panelWidth = math.min(MediaQuery.sizeOf(context).width * 0.78, 320.0);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.10)),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const ValueKey<String>('ai_history_panel'),
              width: panelWidth,
              margin: const EdgeInsets.fromLTRB(12, 12, 0, 96),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(24),
                  left: Radius.circular(18),
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            strings.aiHistoryTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          tooltip: strings.close,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.aiHistorySignedOut,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF647067),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
