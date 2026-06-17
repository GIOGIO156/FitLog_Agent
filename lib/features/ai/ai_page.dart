import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/localization/localization_extensions.dart';

enum AiShellMode { disabled, ready, processing, needsClarification }

enum _AiProvider { chatGpt, qwen }

class AiPage extends StatefulWidget {
  const AiPage({super.key, this.mode = AiShellMode.disabled, this.displayName});

  final AiShellMode mode;
  final String? displayName;

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController _controller = TextEditingController();
  _AiProvider _provider = _AiProvider.chatGpt;
  bool _historyOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => widget.mode != AiShellMode.disabled;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final keyboardVisible = bottomInset > 0;
    final centerBottomPadding = keyboardVisible
        ? math.min(bottomInset + 190.0, mediaQuery.size.height * 0.64)
        : 148.0;
    final composerBottomPadding = keyboardVisible ? bottomInset + 12.0 : 94.0;

    return Stack(
      key: const ValueKey<String>('ai_page'),
      children: <Widget>[
        Positioned.fill(child: _AiAnimatedBackground(mode: widget.mode)),
        SafeArea(
          bottom: false,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, centerBottomPadding),
                  child: Center(
                    child: _AiCenterStatus(
                      mode: widget.mode,
                      displayName: widget.displayName,
                    ),
                  ),
                ),
              ),
              _AiTopBar(
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
                      canSend: _canSend,
                      mode: widget.mode,
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
}

class _AiAnimatedBackground extends StatefulWidget {
  const _AiAnimatedBackground({required this.mode});

  final AiShellMode mode;

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
        return const Duration(seconds: 12);
      case AiShellMode.ready:
      case AiShellMode.needsClarification:
        return const Duration(seconds: 24);
      case AiShellMode.disabled:
        return const Duration(seconds: 60);
    }
  }

  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shouldAnimate = widget.mode != AiShellMode.disabled && !reduceMotion;
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
    final emphasis = mode == AiShellMode.processing ? 1.0 : 0.0;
    final shift = math.sin(progress * math.pi * 2);

    final baseColors = disabled
        ? const <Color>[Color(0xFFF4F5F3), Color(0xFFE9ECE8), Color(0xFFF2F3F1)]
        : const <Color>[
            Color(0xFFF8DDE7),
            Color(0xFFE8F5EC),
            Color(0xFFC7E9F8),
          ];

    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-0.6 + shift * 0.08, -1),
        end: Alignment(0.7 - shift * 0.08, 1),
        colors: baseColors,
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final washPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + shift * 0.12, -0.4),
        end: Alignment(1, 0.8),
        colors: disabled
            ? <Color>[
                Colors.white.withValues(alpha: 0.18),
                const Color(0xFFDDE2DE).withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.18),
              ]
            : <Color>[
                const Color(
                  0xFFFFF5DF,
                ).withValues(alpha: 0.24 + emphasis * 0.08),
                const Color(
                  0xFFBEEAD9,
                ).withValues(alpha: 0.26 + emphasis * 0.08),
                const Color(
                  0xFFD7E6FF,
                ).withValues(alpha: 0.24 + emphasis * 0.08),
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
          Colors.white.withValues(alpha: disabled ? 0.26 : 0.18),
          Colors.white.withValues(alpha: disabled ? 0.06 : 0.02),
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
  const _AiTopBar({required this.onOpenHistory});

  final VoidCallback onOpenHistory;

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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.aiAccountComingSoon)),
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
    required this.onProviderChanged,
  });

  final TextEditingController controller;
  final _AiProvider provider;
  final bool canSend;
  final AiShellMode mode;
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
            _AiStatusPill(
              label: mode == AiShellMode.disabled
                  ? strings.aiSignedOutStatus
                  : strings.aiAvailableStatus,
            ),
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
