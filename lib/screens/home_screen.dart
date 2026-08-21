import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../services/ffmpeg_service.dart';
import '../widgets/common.dart';
import 'files_screen.dart';
import 'options_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  Future<void> _pickVideo() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      final path = result?.files.single.path;
      if (path == null) return;

      final info = await FfmpegService.instance.probe(path);
      if (!mounted) return;
      if (info == null) {
        _showError('این فایل قابل خواندن نیست. لطفاً ویدئوی دیگری انتخاب کنید.');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OptionsScreen(info: info)),
      );
    } catch (e) {
      if (mounted) _showError('خطا در انتخاب فایل');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 26),
              _mainCard(),
              const SizedBox(height: 22),
              _quickStats(),
              const SizedBox(height: 8),
              const SectionTitle(title: 'چرا این برنامه؟'),
              _featureTile(
                Icons.block_rounded,
                'بدون هیچ تبلیغی',
                'هیچ تبلیغی بین مراحل نیست — مستقیم انتخاب کن و شروع کن.',
              ),
              _featureTile(
                Icons.offline_bolt_rounded,
                'کاملاً آفلاین',
                'ویدئو از گوشی شما خارج نمی‌شود و به اینترنت نیازی نیست.',
              ),
              _featureTile(
                Icons.auto_awesome_rounded,
                'کیفیت هوشمند',
                'با روش CRF کیفیت تصویر حفظ می‌شود و فقط حجم اضافه حذف می‌شود.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: AppColors.tealGradient,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.compress_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('فشرده‌سازی ویدئو',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              Text('کم‌حجم کن، کیفیت رو نگه دار',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FilesScreen()),
          ),
          icon: const Icon(Icons.folder_rounded),
          tooltip: 'فایل‌های خروجی',
        ),
      ],
    );
  }

  Widget _mainCard() {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
        decoration: BoxDecoration(
          gradient: AppColors.tealGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
                color: Color(0x4D0DB0B0), blurRadius: 28, offset: Offset(0, 12)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(46),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withAlpha(89), width: 1.5),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.6),
                    )
                  : const Icon(Icons.video_library_rounded,
                      color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            const Text(
              'انتخاب ویدئو',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'ویدئو را انتخاب کن تا در چند ثانیه کم‌حجم شود',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withAlpha(230), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStats() {
    return FutureBuilder<List<FileSystemEntity>>(
      future: _recentFiles(),
      builder: (context, snapshot) {
        final files = snapshot.data ?? const <FileSystemEntity>[];
        if (files.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title: 'آخرین خروجی‌ها',
              action: 'همه',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FilesScreen()),
              ),
            ),
            ...files.take(3).map((f) {
              final file = File(f.path);
              final name = f.path.split('/').last;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: AppStyles.card(radius: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.movie_rounded,
                        color: AppColors.tealLight, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                    Text(Fmt.size(file.lengthSync()),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<List<FileSystemEntity>> _recentFiles() async {
    try {
      final dir = await FfmpegService.instance.outputDirectory();
      final files = dir.listSync().whereType<File>().toList()
        ..sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (_) {
      return [];
    }
  }

  Widget _featureTile(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.card(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.teal.withAlpha(36),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.tealLight, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
