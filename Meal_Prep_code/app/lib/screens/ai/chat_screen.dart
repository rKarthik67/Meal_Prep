import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/emoji_art.dart';
import 'blocks.dart';

const agentEmoji = <String, String>{
  'meal_planner': '📅',
  'cook_matcher': '🧑‍🍳',
  'nutrition_coach': '🥗',
  'cook_assistant': '🍲',
};

IconData agentIcon(String name) => switch (name) {
      'calendar_month' => Icons.calendar_month_rounded,
      'person_search' => Icons.person_search_rounded,
      'monitor_heart' => Icons.monitor_heart_rounded,
      'soup_kitchen' => Icons.soup_kitchen_rounded,
      _ => Icons.auto_awesome_rounded,
    };

/// Conversation with one AI agent. Messages can carry rich blocks (plans, cooks, drafts…).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.agentKey, this.conversationId, this.initialMessage});
  final String agentKey;
  final int? conversationId;
  final String? initialMessage;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  AiCatalog? _catalog;
  int? _conversationId;
  bool _sending = false;
  bool _loading = true;
  String? _error;
  String? _usedProvider;

  AiAgent? get _agent {
    final c = _catalog;
    if (c == null) return null;
    for (final a in c.agents) {
      if (a.key == widget.agentKey) return a;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _init();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final api = context.read<Session>().api;
    try {
      final catalog = await api.aiCatalog();
      List<ChatMessage> history = const [];
      if (_conversationId != null) history = (await api.conversation(_conversationId!)).messages;
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _messages.addAll(history);
        _loading = false;
      });
      _scrollToEnd();
      if (widget.initialMessage != null && history.isEmpty) _send(widget.initialMessage!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 400,
            duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;
    final session = context.read<Session>();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: msg));
      _sending = true;
      _error = null;
      _input.clear();
    });
    _scrollToEnd();
    try {
      final reply = await session.api.aiChat(
        agent: widget.agentKey,
        message: msg,
        conversationId: _conversationId,
        provider: session.aiProvider,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = reply.conversationId;
        _usedProvider = reply.provider;
        _messages.add(reply.message);
      });
      if (reply.message.blocks.any((b) => b['type'] == 'meal_plan')) session.bump(); // a plan was saved
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _messages.removeLast();
        _input.text = msg;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  Future<void> _pickProvider() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final session = context.read<Session>();
    final current = session.aiProvider ?? catalog.defaultProvider;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
            title: Text('AI model provider'),
            subtitle: Text('Configure keys in backend/.env. Demo works offline.'),
          ),
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(children: [
              for (final p in catalog.providers)
                RadioListTile<String>(
                  value: p.$1,
                  title: Text(p.$2),
                  secondary: Icon(switch (p.$1) {
                    'azure' => Icons.cloud_rounded,
                    'anthropic' => Icons.auto_awesome_rounded,
                    'ollama' => Icons.computer_rounded,
                    _ => Icons.science_rounded,
                  }),
                ),
            ]),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (picked != null) await session.setAiProvider(picked == catalog.defaultProvider ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final agent = _agent;
    final color = agent == null ? AppColors.aiViolet : AppColors.fromHex(agent.color);
    final session = context.watch<Session>();
    final providerKey = _usedProvider ?? session.aiProvider ?? _catalog?.defaultProvider;
    final providerLabel = providerKey == null ? null : providerName(_catalog, providerKey);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          _AgentAvatar(emoji: agentEmoji[widget.agentKey] ?? '🤖', color: color, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(agent?.title ?? 'AI assistant', style: Theme.of(context).textTheme.titleMedium),
              Text(
                _sending ? 'thinking…' : (providerLabel ?? 'AI agent'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
              ),
            ]),
          ),
        ]),
        actions: [
          IconButton(tooltip: 'Model', onPressed: _pickProvider, icon: const Icon(Icons.tune_rounded)),
          IconButton(
            tooltip: 'New chat',
            onPressed: _messages.isEmpty
                ? null
                : () => setState(() {
                      _messages.clear();
                      _conversationId = null;
                    }),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? _Welcome(agent: agent, color: color, onPick: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _messages.length) return _TypingBubble(color: color);
                        final m = _messages[i];
                        final isLast = i == _messages.length - 1;
                        return _MessageView(
                          message: m,
                          color: color,
                          emoji: agentEmoji[widget.agentKey] ?? '🤖',
                          showSuggestions: isLast && !_sending,
                          onSuggestion: _send,
                        );
                      },
                    ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          ),
        _InputBar(controller: _input, color: color, sending: _sending, onSend: () => _send(_input.text)),
      ]),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.emoji, required this.color, this.size = 36});
  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: EmojiArt(emoji, size: size * 0.72),
      );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.agent, required this.color, required this.onPick});
  final AiAgent? agent;
  final Color color;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = agent;
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 12),
      Center(child: _AgentAvatar(emoji: agentEmoji[a?.key] ?? '🤖', color: color, size: 110)),
      const SizedBox(height: 16),
      Text(a?.title ?? 'AI assistant', textAlign: TextAlign.center, style: t.headlineSmall),
      const SizedBox(height: 6),
      Text(a?.tagline ?? '', textAlign: TextAlign.center, style: t.bodyMedium),
      const SizedBox(height: 28),
      Text('Try asking', style: t.labelLarge),
      const SizedBox(height: 8),
      for (final s in a?.starters ?? const <String>[])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.chat_bubble_outline_rounded, color: color),
              title: Text(s, style: t.bodyMedium),
              trailing: const Icon(Icons.north_east_rounded, size: 18),
              onTap: () => onPick(s),
            ),
          ),
        ),
    ]);
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.color,
    required this.emoji,
    required this.showSuggestions,
    required this.onSuggestion,
  });
  final ChatMessage message;
  final Color color;
  final String emoji;
  final bool showSuggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final maxW = MediaQuery.of(context).size.width * 0.82;
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          margin: const EdgeInsets.only(bottom: 10, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(message.content, style: t.bodyMedium?.copyWith(color: scheme.onPrimary)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AgentAvatar(emoji: emoji, color: color, size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              constraints: BoxConstraints(maxWidth: maxW),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: t.bodyMedium?.copyWith(height: 1.45),
                  listBullet: t.bodyMedium,
                ),
              ),
            ),
            for (final b in message.blocks)
              Padding(padding: const EdgeInsets.only(top: 10), child: AiBlock(block: b)),
            if (showSuggestions && message.suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in message.suggestions)
                    ActionChip(
                      avatar: Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: color),
                      label: Text(s),
                      onPressed: () => onSuggestion(s),
                    ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.color});
  final Color color;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(
                    opacity: 0.3 + 0.7 * (((_c.value * 3 - i) % 3) < 1 ? 1 : 0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.color, required this.sending, required this.onSend});
  final TextEditingController controller;
  final Color color;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Ask anything about meals, cooks, nutrition…',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
              child: Ink(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [color, Color.lerp(color, AppColors.aiBlue, 0.5)!]),
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Small helper so other screens can show the provider in use.
String providerName(AiCatalog? c, String? key) {
  for (final p in c?.providers ?? const <(String, String)>[]) {
    if (p.$1 == key) return p.$2;
  }
  return 'AI';
}

/// Used by the hub to show a compact error.
Widget aiErrorState(BuildContext context, Object error, VoidCallback retry) =>
    EmptyState(emoji: '🤖', title: 'AI is unavailable', message: '$error', action: 'Retry', onAction: retry);
