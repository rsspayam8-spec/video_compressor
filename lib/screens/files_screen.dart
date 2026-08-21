import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../services/ffmpeg_service.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await FfmpegService.instance.outputDirectory();
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  Future<void> _actions(File file) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(file.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.share_rounded,
                  color: AppColors.tealLight),
              title: const Text('اشتراک‌گذاری',
                  style: TextStyle(fontSize: 14.5)),
              onTap: () async {
                Navigator.pop(context);
                await Share.shareXFiles([XFile(file.path)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded,
                  color: AppColors.tealLight),
              title: const Text('ذخیره در گالری',
                  style: TextStyle(fontSize: 14.5)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await Gal.putVideo(file.path, album: 'فشرده‌سازی ویدئو');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('در گالری ذخیره شد')),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ذخیره ناموفق بود')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('حذف',
                  style: TextStyle(fontSize: 14.5, color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(context);
                if (await file.exists()) await file.delete();
                _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فایل‌های خروجی')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.tealLight))
          : _files.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final stat = file.statSync();
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _actions(file),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: AppStyles.card(radius: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.teal.withAlpha(36),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.movie_rounded,
                                  color: AppColors.tealLight, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.path.split('/').last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Fmt.size(stat.size),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.more_vert_rounded,
                                color: AppColors.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_off_rounded,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 14),
          Text('هنوز فایلی فشرده نکرده‌اید',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('ویدئوهای فشرده‌شده اینجا نمایش داده می‌شوند',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
