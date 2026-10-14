import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../models/user.dart';
import '../shared/app_colors.dart';
import '../state/auth_state.dart';
import '../state/locale_provider.dart';
import '../widgets/language_sheet.dart';
import '../widgets/toast.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/user_avatar.dart';

const _pageBackground = Color(0xFFF4F7FC);
const _danger = Color(0xFFDC2626);

/// The signed-in user's own page: who they are, their name and password,
/// the app language, and signing out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authProvider.select((s) => s.user));
    final locale = ref.watch(localeProvider);
    final languageName = switch (locale?.languageCode) {
      'th' => 'ไทย',
      'en' => 'English',
      _ => l10n.languageSystem,
    };

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: TopNavBar(
        title: l10n.accountTitle,
        backgroundColor: _pageBackground,
      ),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              // Room at the end so a toast never sits on top of "Sign out".
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              children: [
                _ProfileHeader(user: user),
                const SizedBox(height: 28),
                _SectionLabel(l10n.accountProfileSection),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.person_outline_rounded,
                      label: l10n.accountName,
                      value: user.name,
                      onTap: () => _editName(context, ref, user.name),
                    ),
                    _Row(
                      icon: Icons.mail_outline_rounded,
                      label: l10n.accountEmail,
                      value: user.email,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionLabel(l10n.accountSecuritySection),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.lock_outline_rounded,
                      label: l10n.accountChangePassword,
                      onTap: () => _changePassword(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionLabel(l10n.accountPreferencesSection),
                _Group(
                  children: [
                    _Row(
                      icon: Icons.translate_rounded,
                      label: l10n.languageTitle,
                      value: languageName,
                      onTap: () => showLanguageSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    // Needs no context, so it still shows once the redirect
                    // has replaced this screen.
                    AppToast.info(l10n.authSignedOut);
                    if (!context.mounted) return;
                    context.go('/login');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _danger,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(
                    l10n.accountSignOut,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.l10n;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _NameSheet(initial: current),
    );
    if (saved == true) AppToast.success(l10n.accountNameSaved);
  }

  Future<void> _changePassword(BuildContext context) async {
    final l10n = context.l10n;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _PasswordSheet(),
    );
    if (changed == true) AppToast.success(l10n.accountPasswordChanged);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        const SizedBox(height: 8),
        UserAvatar(name: user.name, size: 84),
        const SizedBox(height: 14),
        Text(
          user.name.isEmpty ? user.email : user.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.deepNavy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: AppColors.softBlue.withValues(alpha: .1),
          ),
          child: Text(
            user.isAdmin ? l10n.roleAdmin : l10n.roleMember,
            style: const TextStyle(
              color: AppColors.softBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// White rounded block of rows separated by hairlines; the rows themselves
/// have no corners of their own.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 52, color: AppColors.cardBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.value, this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.deepNavy),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.deepNavy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ?? '',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet body: a title, the fields, and one button, above the keyboard.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.deepNavy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

InputDecoration _field(String label, {String? error}) => InputDecoration(
  labelText: label,
  errorText: error,
  filled: true,
  fillColor: const Color(0xFFF7F9FC),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.cardBorder),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.cardBorder),
  ),
);

Widget _saveButton({
  required bool busy,
  required String label,
  required VoidCallback onPressed,
}) => FilledButton(
  onPressed: busy ? null : onPressed,
  style: FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(50),
    backgroundColor: AppColors.softBlue,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  child: busy
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : Text(label),
);

class _NameSheet extends ConsumerStatefulWidget {
  const _NameSheet({required this.initial});
  final String initial;

  @override
  ConsumerState<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends ConsumerState<_NameSheet> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.accountNameRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(authProvider.notifier).updateName(name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
      AppToast.error(l10n.accountSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SheetBody(
      title: l10n.accountEditName,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _save(),
          decoration: _field(l10n.accountName, error: _error),
        ),
        const SizedBox(height: 16),
        _saveButton(busy: _busy, label: l10n.commonSave, onPressed: _save),
      ],
    );
  }
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError, _nextError, _confirmError;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() {
      _currentError = _current.text.isEmpty
          ? l10n.accountCurrentRequired
          : null;
      _nextError = _next.text.length < 6 ? l10n.accountPasswordTooShort : null;
      _confirmError = _confirm.text != _next.text
          ? l10n.accountPasswordMismatch
          : null;
    });
    if (_currentError != null || _nextError != null || _confirmError != null) {
      return;
    }

    setState(() => _busy = true);
    final result = await ref
        .read(authProvider.notifier)
        .changePassword(_current.text, _next.text);
    if (!mounted) return;
    switch (result) {
      case PasswordChange.done:
        Navigator.of(context).pop(true);
      case PasswordChange.wrongCurrent:
        setState(() {
          _busy = false;
          _currentError = l10n.accountPasswordWrong;
        });
      case PasswordChange.failed:
        setState(() => _busy = false);
        AppToast.error(l10n.accountSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SheetBody(
      title: l10n.accountChangePassword,
      children: [
        TextField(
          controller: _current,
          obscureText: true,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: _field(l10n.accountCurrentPassword, error: _currentError),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _next,
          obscureText: true,
          textInputAction: TextInputAction.next,
          decoration: _field(l10n.accountNewPassword, error: _nextError),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: _field(l10n.accountConfirmPassword, error: _confirmError),
        ),
        const SizedBox(height: 16),
        _saveButton(busy: _busy, label: l10n.commonSave, onPressed: _save),
      ],
    );
  }
}
