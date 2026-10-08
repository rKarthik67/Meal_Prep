import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../state/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/emoji_art.dart';
import '../../widgets/skeleton.dart';
import 'chat_screen.dart';

/// Pick an AI agent or continue a previous conversation.
class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen> {
  late Future<(AiCatalog, List<Conversation>)> _future = _load();

  Future<(AiCatalog, List<Conversation>)> _load() async {
    final api = context.read<Session>().api;
    final catalog = await api.aiCatalog();
    final convs = await api.conversations();
    return (catalog, convs);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final session = context.watch<Session>();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<(AiCatalog, List<Conversation>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return aiErrorState(context, snap.error!, _reload);
            final data = snap.data;
            final catalog = data?.$1;
            return ListView(padding: const EdgeInsets.only(bottom: 100), children: [
              // ---------------- hero
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: AppColors.aiGradient, borderRadius: BorderRadius.circular(28)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AI kitchen team',
                          style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'Specialist agents that plan meals, crunch nutrition, shop and book cooks for you.',
                        style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: catalog == null ? null : () => _pickProvider(catalog),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.memory_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              catalog == null
                                  ? 'Loading…'
                                  : providerName(catalog, session.aiProvider ?? catalog.defaultProvider),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            const Icon(Icons.expand_more_rounded, color: Colors.white, size: 16),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  const EmojiArt('🤖', size: 96),
                ]),
              ),
              // ---------------- agents
              const SectionHeader('Choose an agent'),
              if (catalog == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    Skeleton(height: 84),
                    SizedBox(height: 10),
                    Skeleton(height: 84),
                    SizedBox(height: 10),
                    Skeleton(height: 84),
                  ]),
                )
              else
                for (final a in catalog.agents)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _AgentCard(agent: a, onTap: () => _open(ChatScreen(agentKey: a.key))),
                  ),
              // ---------------- history
              if (data != null && data.$2.isNotEmpty) ...[
                const SectionHeader('Recent chats'),
                for (final c in data.$2.take(15).toList())
                  Dismissible(
                    key: ValueKey('conv${c.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Icon(Icons.delete_outline_rounded),
                    ),
                    onDismissed: (_) {
                      setState(() => data.$2.remove(c));
                      context.read<Session>().api.deleteConversation(c.id);
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.aiViolet.withValues(alpha: 0.1),
                        child: EmojiArt(agentEmoji[c.agent] ?? '🤖', size: 26),
                      ),
                      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(c.preview.replaceAll(RegExp(r'[*_#`]'), ''),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(prettyDate(c.updatedAt.toLocal()), style: t.labelSmall),
                      onTap: () => _open(ChatScreen(agentKey: c.agent, conversationId: c.id)),
                    ),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text(
                  'AI can make mistakes. Bookings and profile changes always need your confirmation.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall,
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _pickProvider(AiCatalog catalog) async {
    final session = context.read<Session>();
    final current = session.aiProvider ?? catalog.defaultProvider;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('AI model provider'), subtitle: Text('Only providers configured on the server are listed.')),
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(children: [
              for (final p in catalog.providers) RadioListTile<String>(value: p.$1, title: Text(p.$2)),
            ]),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (picked != null) await session.setAiProvider(picked == catalog.defaultProvider ? null : picked);
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent, required this.onTap});
  final AiAgent agent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.fromHex(agent.color);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
              child: EmojiArt(agentEmoji[agent.key] ?? '🤖', size: 44),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(agentIcon(agent.icon), size: 16, color: c),
                  const SizedBox(width: 6),
                  Flexible(child: Text(agent.title, style: t.titleMedium)),
                ]),
                const SizedBox(height: 2),
                Text(agent.tagline, style: t.bodySmall),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c),
          ]),
        ),
      ),
    );
  }
}
