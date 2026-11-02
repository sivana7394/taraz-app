// راه‌اندازی اولیه: خوش‌آمد، انتخاب نقش، اتصال (ساخت پروژه / کد دعوت / نمایشی).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../data/app_state.dart';
import '../../data/firebase_config.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../widgets/common.dart';

class SetupFlow extends StatefulWidget {
  const SetupFlow({super.key});

  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> {
  final _page = PageController();

  void _go(int i) => _page.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _page,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _Welcome(onNext: () => _go(1)),
            _ConnectPage(onBack: () => _go(0)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Welcome extends StatelessWidget {
  const _Welcome({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(Icons.balance, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 24),
          Text('تراز', style: text.displaySmall?.copyWith(color: scheme.primary)),
          const SizedBox(height: 6),
          Text('حسابداری مشارکت ساخت‌وساز', style: text.titleLarge),
          const SizedBox(height: 16),
          Text(
            'یک حساب مشترک برای همهٔ شرکا: هر کس از گوشی خودش هزینه را — با موضوع، مبلغ، تاریخ و عکس رسید — ثبت می‌کند و همان لحظه روی گوشی بقیه دیده می‌شود. اپ خودش جمع می‌زند، سهم هر طرف را حساب می‌کند و می‌گوید کی به کی بدهکار است.',
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          for (final (icon, t) in [
            (Icons.sync, 'همگام‌سازی آنی و کار بدون اینترنت'),
            (Icons.receipt_long_outlined, 'عکس رسید از گالری: Share ← تراز'),
            (Icons.pie_chart_outline, 'داشبورد، نمودار و خروجی اکسل/PDF'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [Icon(icon, color: scheme.primary, size: 20), const SizedBox(width: 10), Text(t, style: text.bodyMedium)]),
            ),
          const Spacer(flex: 2),
          FilledButton(onPressed: onNext, child: const Text('شروع')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _ConnectPage extends StatefulWidget {
  const _ConnectPage({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<_ConnectPage> {
  int _mode = 0; // 0 = انتخاب، 1 = ساخت پروژه، 2 = پیوستن
  final _configCtl = TextEditingController();
  final _inviteCtl = TextEditingController();
  final _nameCtl = TextEditingController(text: 'پروژهٔ ساخت');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _configCtl.dispose();
    _inviteCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final parsed = FirebaseConn.parseConsoleText(_configCtl.text);
    if (parsed == null) {
      setState(() => _error = 'متن تنظیمات شناخته نشد. کل قطعهٔ firebaseConfig (یا محتوای google-services.json) را کپی کنید.');
      return;
    }
    final conn = parsed.copyWith(roomId: FirebaseConn.newRoomId());
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().connectWith(
            conn,
            createRoom: RoomConfig(name: _nameCtl.text.trim().isEmpty ? 'پروژهٔ ساخت' : _nameCtl.text.trim()),
          );
      // پس از اتصال، صفحهٔ خانه نمایش داده می‌شود و خودش برگهٔ کد دعوت را باز می‌کند.
    } on ConnError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final conn = FirebaseConn.fromInviteCode(_inviteCtl.text);
    if (conn == null) {
      setState(() => _error = 'کد دعوت معتبر نیست. کل متن کد (که با TARAZ1- شروع می‌شود) را جای‌گذاری کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().connectWith(conn);
    } on ConnError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteInto(TextEditingController c) async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) setState(() => c.text = d!.text!);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        Row(
          children: [
            IconButton(onPressed: _mode == 0 ? widget.onBack : () => setState(() => _mode = 0), icon: const Icon(Icons.arrow_back)),
          ],
        ),
        const SizedBox(height: 8),
        if (_mode == 0) ...[
          Text('اتصال به پروژه', style: text.headlineSmall),
          const SizedBox(height: 6),
          Text('داده‌ها در یک پایگاه‌دادهٔ رایگان Firebase (گوگل) ذخیره می‌شود که فقط متعلق به شماست.', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          _Option(
            icon: Icons.add_circle_outline,
            title: 'ساخت پروژهٔ جدید',
            subtitle: 'برای مدیر پروژه — یک بار با راهنمای قدم‌به‌قدم',
            onTap: () => setState(() => _mode = 1),
          ),
          const SizedBox(height: 12),
          _Option(
            icon: Icons.vpn_key_outlined,
            title: 'پیوستن با کد دعوت',
            subtitle: 'کدی که مدیر پروژه برایتان فرستاده',
            onTap: () => setState(() => _mode = 2),
          ),
          const SizedBox(height: 12),
          _Option(
            icon: Icons.science_outlined,
            title: 'حالت نمایشی',
            subtitle: 'گشت‌وگذار در اپ با داده‌های نمونه، بدون اینترنت',
            onTap: () => s.startDemo(),
          ),
        ] else if (_mode == 1) ...[
          Text('ساخت پروژهٔ جدید', style: text.headlineSmall),
          const SizedBox(height: 6),
          Text('این کار را فقط مدیر پروژه یک بار انجام می‌دهد (حدود ۵ دقیقه). برای ورود به کنسول گوگل احتمالاً به فیلترشکن نیاز دارید.', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          const _GuideSteps(),
          const SizedBox(height: 18),
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(labelText: 'نام پروژه', prefixIcon: Icon(Icons.apartment_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _configCtl,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'تنظیمات Firebase (قدم ۵)',
              hintText: 'const firebaseConfig = { apiKey: "...", ... }',
              alignLabelWithHint: true,
              suffixIcon: IconButton(icon: const Icon(Icons.content_paste), tooltip: 'جای‌گذاری', onPressed: () => _pasteInto(_configCtl)),
            ),
          ),
          if (_error != null) _ErrorBox(_error!),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_done_outlined),
            label: Text(_busy ? 'در حال بررسی اتصال…' : 'اتصال و ساخت پروژه'),
          ),
        ] else ...[
          Text('پیوستن با کد دعوت', style: text.headlineSmall),
          const SizedBox(height: 6),
          Text('کدی را که مدیر پروژه از بخش «تنظیمات ← کد دعوت شرکا» برایتان فرستاده، این‌جا جای‌گذاری کنید.', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          TextField(
            controller: _inviteCtl,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'کد دعوت',
              hintText: 'TARAZ1-…',
              alignLabelWithHint: true,
              suffixIcon: IconButton(icon: const Icon(Icons.content_paste), tooltip: 'جای‌گذاری', onPressed: () => _pasteInto(_inviteCtl)),
            ),
          ),
          if (_error != null) _ErrorBox(_error!),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _join,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login),
            label: Text(_busy ? 'در حال اتصال…' : 'پیوستن'),
          ),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.errorContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}

/// راهنمای قدم‌به‌قدم ساخت پروژهٔ Firebase، با دکمه‌های کپی.
class _GuideSteps extends StatelessWidget {
  const _GuideSteps();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final steps = <(String, String, String?, String?)>[
      (
        'ورود به کنسول',
        'در مرورگر به console.firebase.google.com بروید و با حساب گوگل وارد شوید.',
        'console.firebase.google.com',
        'آدرس کپی شد',
      ),
      (
        'ساخت پروژه',
        'روی «Create a project» بزنید، نام دلخواه (مثلاً taraz) بدهید، Google Analytics را خاموش کنید و Create را بزنید.',
        null,
        null,
      ),
      (
        'ساخت پایگاه‌داده',
        'از منوی چپ: Build ← Firestore Database ← Create database. محل سرور را مثلاً eur3 (Europe) انتخاب کنید، گزینهٔ «Start in production mode» را بزنید و Enable کنید.',
        null,
        null,
      ),
      (
        'قوانین دسترسی',
        'در صفحهٔ Firestore، زبانهٔ Rules را باز کنید، همهٔ متن را پاک کنید، متن زیر را (با دکمهٔ کپی) جای‌گذاری و Publish کنید.',
        firestoreRulesText,
        'قوانین کپی شد؛ در زبانهٔ Rules جای‌گذاری کنید',
      ),
      (
        'گرفتن تنظیمات',
        'از چرخ‌دندهٔ کنار Project Overview ← Project settings بروید. پایین صفحه در «Your apps» آیکون </> (Web) را بزنید، یک نام بدهید و Register app را بزنید. قطعهٔ firebaseConfig را کپی کنید و در کادر پایین همین صفحه جای‌گذاری کنید.',
        null,
        null,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(faDigits(i + 1), style: text.labelLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$1, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(steps[i].$2, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.6)),
                      if (steps[i].$3 != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                            onPressed: () => copyWithToast(context, steps[i].$3!, message: steps[i].$4!),
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: Text(i == 0 ? 'کپی آدرس' : 'کپی متن قوانین'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
