// تنظیمات: پروژه، طرف‌ها، سهم‌ها، واحد، ظاهر، کد دعوت، قفل، خروج.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/firebase_config.dart';
import '../../data/models.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cfg = s.config;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          // ------------------------------------------------------- پروژه
          _Group(
            title: 'پروژه و طرف‌ها',
            children: [
              ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: const Text('نام پروژه'),
                subtitle: Text(cfg.name),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editText(context, 'نام پروژه', cfg.name, (v) => s.saveConfig(cfg.copyWith(name: v))),
              ),
              ListTile(
                leading: Container(width: 10, height: 10, margin: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Palette.sideA, shape: BoxShape.circle)),
                title: const Text('نام طرف اول'),
                subtitle: Text('${cfg.sideAName} — ${faDigits(cfg.shareA)} دانگ'),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editSide(context, Side.a),
              ),
              ListTile(
                leading: Container(width: 10, height: 10, margin: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Palette.sideB, shape: BoxShape.circle)),
                title: const Text('نام طرف دوم'),
                subtitle: Text('${cfg.sideBName} — ${faDigits(cfg.shareB)} دانگ'),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editSide(context, Side.b),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('این گوشی متعلق به'),
                subtitle: Text(s.myName),
                trailing: const Icon(Icons.swap_horiz, size: 18),
                onTap: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'تغییر نقش این گوشی',
                    message: 'هزینه‌هایی که از این گوشی ثبت می‌شود به نام «${s.otherName}» خواهد بود. ادامه می‌دهید؟',
                    okLabel: 'تغییر',
                    destructive: false,
                  );
                  if (ok) await s.setSide(s.otherSide);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------------- نمایش
          _Group(
            title: 'نمایش',
            children: [
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('واحد پول'),
                trailing: SegmentedButton<MoneyUnit>(
                  segments: const [
                    ButtonSegment(value: MoneyUnit.toman, label: Text('تومان')),
                    ButtonSegment(value: MoneyUnit.rial, label: Text('ریال')),
                  ],
                  selected: {s.unit},
                  onSelectionChanged: (v) => s.setUnit(v.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('پوسته'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18)),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined, size: 18)),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => s.setThemeMode(v.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------------- اتصال
          _Group(
            title: 'اتصال و دعوت',
            children: [
              if (s.isDemo)
                ListTile(
                  leading: Icon(Icons.science_outlined, color: scheme.tertiary),
                  title: const Text('حالت نمایشی'),
                  subtitle: const Text('داده‌ها نمونه‌اند و جایی ذخیره نمی‌شوند.'),
                  trailing: TextButton(onPressed: () => s.disconnect(), child: const Text('اتصال واقعی')),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('پروژهٔ Firebase'),
                  subtitle: Text(s.conn?.projectId ?? '—'),
                  trailing: SyncChip(s.sync),
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text('کد دعوت شرکا'),
                  subtitle: const Text('این کد را برای طرف مقابل بفرستید تا به همین پروژه وصل شود.'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => showInviteSheet(context),
                ),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('قوانین پایگاه‌داده (Rules)'),
                  subtitle: const Text('اگر در کنسول Firebase لازم شد، کپی کنید.'),
                  trailing: const Icon(Icons.copy_outlined, size: 18),
                  onTap: () => copyWithToast(context, firestoreRulesText, message: 'قوانین کپی شد'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------------- امنیت
          _Group(
            title: 'امنیت',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: const Text('قفل اپ با رمز'),
                subtitle: Text(s.hasPin ? 'فعال — هنگام باز شدن اپ رمز خواسته می‌شود' : 'غیرفعال'),
                value: s.hasPin,
                onChanged: (v) async {
                  if (!v) {
                    await s.setPin(null);
                  } else {
                    final pin = await _askPin(context);
                    if (pin != null) await s.setPin(pin);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------------- خروج
          _Group(
            title: 'خروج',
            children: [
              ListTile(
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text('خروج از این پروژه', style: TextStyle(color: scheme.error)),
                subtitle: const Text('اتصال و نقش این گوشی پاک می‌شود؛ داده‌های پروژه روی سرور می‌ماند.'),
                onTap: () async {
                  final ok = await confirmDialog(context, title: 'خروج از پروژه', message: 'برای اتصال دوباره به کد دعوت یا تنظیمات Firebase نیاز دارید. خارج می‌شوید؟', okLabel: 'خروج');
                  if (ok) await s.disconnect();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text('تراز', style: text.titleMedium?.copyWith(color: scheme.primary)),
                Text('حسابداری مشارکت ساخت‌وساز · نسخهٔ ۱.۰', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editText(BuildContext context, String title, String initial, Future<void> Function(String) onSave) async {
    final ctl = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, autofocus: true, textInputAction: TextInputAction.done, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('ذخیره')),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) await onSave(v.trim());
  }

  Future<void> _editSide(BuildContext context, Side side) async {
    final s = context.read<AppState>();
    final cfg = s.config;
    final nameCtl = TextEditingController(text: cfg.sideName(side));
    var share = cfg.share(side);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(side == Side.a ? 'طرف اول' : 'طرف دوم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtl, autofocus: true, decoration: const InputDecoration(labelText: 'نام')),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Text('سهم (دانگ)')),
                  IconButton(onPressed: share > 1 ? () => setSt(() => share--) : null, icon: const Icon(Icons.remove_circle_outline)),
                  Text(faDigits(share), style: Theme.of(ctx).textTheme.titleLarge),
                  IconButton(onPressed: share < 5 ? () => setSt(() => share++) : null, icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
              Text('سهم طرف دیگر خودکار ${faDigits(6 - share)} دانگ می‌شود.', style: Theme.of(ctx).textTheme.labelSmall),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    if (res == true) {
      final name = nameCtl.text.trim().isEmpty ? cfg.sideName(side) : nameCtl.text.trim();
      final next = side == Side.a
          ? cfg.copyWith(sideAName: name, shareA: share, shareB: 6 - share)
          : cfg.copyWith(sideBName: name, shareB: share, shareA: 6 - share);
      await s.saveConfig(next);
    }
  }

  Future<String?> _askPin(BuildContext context) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تعیین رمز'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: c1, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'رمز (۴ تا ۸ رقم)')),
              TextField(controller: c2, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: InputDecoration(labelText: 'تکرار رمز', errorText: err)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                final a = enDigits(c1.text), b = enDigits(c2.text);
                if (a.length < 4) {
                  setSt(() => err = 'حداقل ۴ رقم');
                } else if (a != b) {
                  setSt(() => err = 'رمزها یکسان نیستند');
                } else {
                  Navigator.pop(ctx, a);
                }
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
          child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// برگهٔ کد دعوت.
Future<void> showInviteSheet(BuildContext context) {
  final s = context.read<AppState>();
  final code = s.inviteCode();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('کد دعوت شرکا', style: text.titleLarge),
            const SizedBox(height: 6),
            Text(
              'طرف مقابل اپ «تراز» را نصب می‌کند، در صفحهٔ اول «پیوستن با کد دعوت» را می‌زند و این کد را جای‌گذاری می‌کند. هر کس این کد را داشته باشد به داده‌های پروژه دسترسی دارد؛ فقط برای شرکا بفرستید.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            if (code == null)
              const Text('کد دعوت فقط برای پروژه‌های متصل به Firebase ساخته می‌شود.')
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
                child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), textDirection: TextDirection.ltr, maxLines: 6),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => copyWithToast(ctx, code, message: 'کد دعوت کپی شد'),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('کپی'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => SharePlus.instance.share(ShareParams(text: 'کد دعوت اپ تراز — پروژهٔ ${s.config.name}:\n$code')),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('ارسال'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
