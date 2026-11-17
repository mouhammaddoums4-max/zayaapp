import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Écrire à l'assistance : un sujet, un message. Les problèmes de sécurité sont prioritaires côté serveur.
class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  final _message = TextEditingController();
  late String _category =
      supportCategories.contains(widget.initialCategory) ? widget.initialCategory! : supportCategories.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.s;
    final text = _message.text.trim();
    if (text.length < 10) {
      setState(() => _error = s.supportMessageTooShort);
      return;
    }
    final repo = Session.read(context).repo;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.createSupportTicket(category: _category, message: text);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(s.supportSent), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().contains('SUPPORT_RATE_LIMITED') ? s.supportRateLimited : friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.supportTitle)),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
              ZPickerField<String>(
                label: s.supportCategoryLabel,
                options: {for (final c in supportCategories) c: s.supportCategory(c)},
                value: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 16),
              if (_category == 'safety') ...[
                InfoBanner(tone: BannerTone.warning, icon: Icons.priority_high, text: s.supportSafetyNotice),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _message,
                minLines: 6,
                maxLines: 12,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _category == 'translation' ? s.supportTranslationHint : s.supportMessageHint,
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                InfoBanner(tone: BannerTone.danger, icon: Icons.error_outline, text: _error!),
              ],
              const SizedBox(height: 12),
              InfoBanner(icon: Icons.shield_outlined, text: s.supportCodeWarning),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: GradientButton(
              label: s.send,
              icon: Icons.send,
              busy: _busy,
              onPressed: _busy || _message.text.trim().isEmpty ? null : _submit,
            ),
          ),
        ]),
      ),
    );
  }
}

/// Mes demandes : statut et réponse de l'assistance (lecture seule).
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  late Future<List<SupportTicket>> _tickets = Session.read(context).repo.mySupportTickets();

  void _reload() {
    final next = Session.read(context).repo.mySupportTickets();
    setState(() {
      _tickets = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.myRequestsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'support-new',
        icon: const Icon(Icons.edit_outlined),
        label: Text(s.helpWriteSupport),
        onPressed: () async {
          await Navigator.of(context).push(zRoute<void>(const SupportRequestScreen()));
          if (mounted) _reload();
        },
      ),
      body: FutureBuilder<List<SupportTicket>>(
        future: _tickets,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.wifi_off,
              title: s.loadError,
              message: '',
              action: OutlinedButton(onPressed: _reload, child: Text(s.retry)),
            );
          }
          final tickets = snapshot.data ?? const <SupportTicket>[];
          if (tickets.isEmpty) {
            return EmptyState(
                icon: Icons.inbox_outlined, title: s.myRequestsEmptyTitle, message: s.myRequestsEmptyBody);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => FadeSlideIn(index: i, child: _TicketCard(ticket: tickets[i])),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final answered = ticket.reply != null && ticket.reply!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s.supportCategory(ticket.category), style: Theme.of(context).textTheme.titleMedium)),
          ZTag(s.supportStatus(ticket.status)),
        ]),
        const SizedBox(height: 4),
        Text(formatDate(ticket.createdAt), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(ticket.message, style: Theme.of(context).textTheme.bodyMedium),
        if (answered) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.supportReplyLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(ticket.reply!, style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
        ],
      ]),
    );
  }
}
