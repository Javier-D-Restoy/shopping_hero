import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/models/share_invitation_model.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<ShareInvitation> _invitations = const [];
  final Set<String> _respondingTo = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvitations());
  }

  Future<void> _loadInvitations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invitations = await context
          .read<ShoppingProvider>()
          .getPendingShareInvitations();
      if (!mounted) return;
      setState(() => _invitations = invitations);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(ShareInvitation invitation, bool accept) async {
    setState(() => _respondingTo.add(invitation.id));
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      await context.read<ShoppingProvider>().respondToShareInvitation(
        listId: invitation.listId,
        accept: accept,
      );
      if (!mounted) return;
      await _loadInvitations();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Has aceptado compartir "${invitation.listName}".'
                : 'Has rechazado la invitación a "${invitation.listName}".',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _respondingTo.remove(invitation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('  Notificaciones')),
      body: RefreshIndicator(
        color: themeProvider.primaryColor,
        onRefresh: _loadInvitations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _buildInvitationsSection(themeProvider),
            const Divider(height: 1),
            _buildGeneralNotificationsSection(themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationsSection(ThemeProvider themeProvider) {
    if (_isLoading) {
      return const ListTile(
        title: Text('Cargando invitaciones...'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return ListTile(
        title: const Text('No se pudieron cargar las invitaciones'),
        trailing: IconButton(
          tooltip: 'Reintentar',
          onPressed: _loadInvitations,
          icon: const Icon(Icons.refresh),
        ),
      );
    }

    if (_invitations.isEmpty) {
      return const ListTile(title: Text('No hay invitaciones'));
    }

    return ExpansionTile(
      title: const Text('Invitaciones recibidas'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: themeProvider.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${_invitations.length}',
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.expand_more, color: themeProvider.textMutedColor),
        ],
      ),
      children: [
        for (final invitation in _invitations)
          _buildInvitation(invitation, themeProvider),
      ],
    );
  }

  Widget _buildInvitation(
    ShareInvitation invitation,
    ThemeProvider themeProvider,
  ) {
    final isResponding = _respondingTo.contains(invitation.id);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.cardShadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invitation.ownerDisplayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: themeProvider.textStrongColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            invitation.ownerEmail,
            style: TextStyle(color: themeProvider.textMutedColor),
          ),
          const SizedBox(height: 12),
          Text(
            'Quiere compartir contigo la lista:',
            style: TextStyle(color: themeProvider.textStrongColor),
          ),
          const SizedBox(height: 4),
          Text(
            invitation.listName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: themeProvider.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isResponding
                      ? null
                      : () => _respond(invitation, false),
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isResponding
                      ? null
                      : () => _respond(invitation, true),
                  icon: isResponding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralNotificationsSection(ThemeProvider themeProvider) {
    return ExpansionTile(
      leading: Icon(
        Icons.notifications_none_outlined,
        color: themeProvider.primaryColor,
      ),
      title: const Text('Notificaciones generales'),
      children: [
        ListTile(
          leading: Icon(
            Icons.inbox_outlined,
            color: themeProvider.textMutedColor,
          ),
          title: Text(
            'No hay notificaciones nuevas.',
            style: TextStyle(color: themeProvider.textMutedColor),
          ),
        ),
      ],
    );
  }
}
