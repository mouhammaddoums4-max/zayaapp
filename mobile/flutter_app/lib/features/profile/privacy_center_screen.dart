import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Centre de confidentialité et de sécurité : visibilité, discrétion, blocages et données personnelles.
/// Toutes ces protections sont gratuites.
class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  bool _busy = false;

  /// Exécute une action, recharge le profil et affiche le résultat. Retourne `true` en cas de succès.
  Future<bool> _run(Future<void> Function() action, {String? done}) async {
    final session = Session.read(context);
    setState(() => _busy = true);
    var success = false;
    try {
      await action();
      await session.refresh();
      success = true;
      if (mounted && done != null) showZayaSnack(context, done);
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return success;
  }

  Future<void> _setStatus(String status) async {
    final session = Session.read(context);
    if (session.me?.status == status) return;
    final ok = await _run(() => session.repo.setProfileStatus(status));
    if (ok) session.feed.load();
  }

  Future<void> _export() async {
    final repo = Session.read(context).repo;
    setState(() => _busy = true);
    String? json;
    try {
      json = await repo.exportMyData();
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final data = json;
    if (data == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vos données personnelles'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: SingleChildScrollView(
            child: SelectableText(data, style: const TextStyle(fontSize: 12, height: 1.35)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Fermer')),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) showZayaSnack(context, 'Données copiées. Collez-les dans un fichier pour les conserver.');
            },
            child: const Text('Copier'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestDeletion() async {
    final session = Session.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer mon compte ?'),
        content: const Text(
          'Votre profil sera immédiatement retiré de la découverte.\n\n'
          'Votre compte et vos données seront ensuite supprimés définitivement à l’issue d’un délai de rétractation, '
          'pendant lequel vous pouvez annuler. La date vous sera indiquée après votre demande.\n\n'
          'Certaines informations peuvent être conservées plus longtemps lorsque la loi ou la sécurité des membres l’exige.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ZColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Demander la suppression'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await _run(() async {
      await session.repo.requestAccountDeletion();
    }, done: 'Demande de suppression enregistrée.');
    if (done) session.feed.load();
  }

  Future<void> _cancelDeletion() async {
    final session = Session.read(context);
    final done = await _run(() => session.repo.cancelAccountDeletion(),
        done: 'Suppression annulée. Votre profil est de nouveau proposé.');
    if (done) session.feed.load();
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final deletion = me.deletionScheduledFor;

    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité et sécurité')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
            if (_busy) const LinearProgressIndicator(minHeight: 3, color: ZColors.primary),
            const SectionTitle('Visibilité du profil'),
            if (deletion != null)
              InfoBanner(
                tone: BannerTone.danger,
                icon: Icons.delete_outline,
                text: 'Suppression du compte prévue le ${formatDate(deletion)}. '
                    'D’ici là, votre profil n’est plus proposé et vous pouvez annuler votre demande.',
                action: TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: const Size(0, 34), foregroundColor: ZColors.danger),
                  onPressed: _cancelDeletion,
                  child: const Text('Annuler la suppression', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              )
            else ...[
              ChoiceTile(
                icon: Icons.visibility_outlined,
                label: 'Visible',
                subtitle: 'Votre profil est proposé dans la découverte.',
                selected: me.status == 'active',
                onTap: () => _setStatus('active'),
              ),
              ChoiceTile(
                icon: Icons.pause_circle_outline,
                label: 'En pause',
                subtitle: 'Vous n’êtes plus proposé. Vos matchs voient toujours votre profil.',
                selected: me.status == 'paused',
                onTap: () => _setStatus('paused'),
              ),
              ChoiceTile(
                icon: Icons.visibility_off_outlined,
                label: 'Masqué',
                subtitle: 'Votre profil est invisible pour tous. Vos conversations sont conservées.',
                selected: me.status == 'hidden',
                onTap: () => _setStatus('hidden'),
              ),
            ],
            const SizedBox(height: 10),
            const SectionTitle('Discrétion'),
            _Group(children: [
              SwitchListTile(
                value: me.incognito,
                activeThumbColor: ZColors.primary,
                title: const Text('Mode incognito'),
                subtitle: const Text('Votre profil n’est montré qu’aux personnes que vous avez aimées.'),
                onChanged: (v) => _run(() => session.repo.updatePrivacy(incognito: v)),
              ),
              const Divider(indent: 16),
              SwitchListTile(
                value: me.discreetBrowsing,
                activeThumbColor: ZColors.primary,
                title: const Text('Navigation discrète'),
                subtitle: const Text('Vous n’apparaissez pas dans la liste des visiteurs des profils consultés.'),
                onChanged: (v) => _run(() => session.repo.updatePrivacy(discreetBrowsing: v)),
              ),
              const Divider(indent: 16),
              SwitchListTile(
                value: me.showOnline,
                activeThumbColor: ZColors.primary,
                title: const Text('Afficher mon activité'),
                subtitle: const Text('Indiquer aux autres membres quand vous êtes en ligne.'),
                onChanged: (v) => _run(() => session.repo.updatePrivacy(showOnline: v)),
              ),
            ]),
            const SizedBox(height: 10),
            const SectionTitle('Sécurité'),
            _Group(children: [
              ListTile(
                leading: const Icon(Icons.block, color: ZColors.primaryDark),
                title: const Text('Personnes bloquées'),
                subtitle: const Text('Consulter la liste et débloquer'),
                trailing: const Icon(Icons.chevron_right, color: ZColors.muted),
                onTap: () => Navigator.of(context).push(zRoute<void>(const BlockedUsersScreen())),
              ),
            ]),
            const SizedBox(height: 10),
            const SectionTitle('Mes données'),
            _Group(children: [
              ListTile(
                leading: const Icon(Icons.download_outlined, color: ZColors.primaryDark),
                title: const Text('Télécharger mes données'),
                subtitle: const Text('Obtenir une copie de vos informations'),
                onTap: _export,
              ),
              if (deletion == null) ...[
                const Divider(indent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: ZColors.danger),
                  title: const Text('Supprimer mon compte', style: TextStyle(color: ZColors.danger)),
                  subtitle: const Text('Suppression définitive après un délai de rétractation'),
                  onTap: _requestDeletion,
                ),
              ],
            ]),
            const SizedBox(height: 16),
            Text(
              'Bloquer, signaler, masquer son profil, exporter et supprimer ses données sont gratuits pour tous les membres.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ZColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

/// Liste des personnes bloquées, avec déblocage.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<BlockedUser>> _future = Session.read(context).repo.blockedUsers();

  Future<void> _unblock(BlockedUser user) async {
    final session = Session.read(context);
    try {
      await session.repo.unblock(user.userId);
      if (!mounted) return;
      showZayaSnack(context, '${user.displayName} est débloqué(e).');
      setState(() {
        _future = session.repo.blockedUsers();
      });
      session.feed.load();
    } catch (e) {
      if (mounted) showZayaSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personnes bloquées')),
      body: FutureBuilder<List<BlockedUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data;
          if (snapshot.hasError || users == null) {
            return const EmptyState(
              icon: Icons.wifi_off,
              title: 'Connexion interrompue',
              message: 'La liste ne peut pas être chargée pour le moment.',
            );
          }
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.block,
              title: 'Aucune personne bloquée',
              message: 'Les personnes que vous bloquez ne peuvent plus voir votre profil ni vous écrire.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(indent: 76),
            itemBuilder: (context, i) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: ProfileAvatar(name: users[i].displayName, size: 46),
              title: Text(users[i].displayName),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _unblock(users[i]),
                child: const Text('Débloquer'),
              ),
            ),
          );
        },
      ),
    );
  }
}
