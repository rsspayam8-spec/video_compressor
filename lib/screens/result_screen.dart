import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/compress_models.dart';
import '../widgets/common.dart';

class ResultScreen extends StatefulWidget {
  final MediaInfo info;
  final CompressOptions options;
  final String outputPath;
  final int outputBytes;
  final Duration elapsed;

  const ResultScreen({
    super.key,
    required this.info,
    required this.options,
    required this.outputPath,
    required this.outputBytes,
    required this.elapsed,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _savedToGallery = false;

  double get _savingPercent {
    if (widget.info.sizeBytes <= 0) return 0;
    final saved = widget.info.sizeBytes - widget.outputBytes;
    return (saved / widget.info.sizeBytes * 100).clamp(0.0, 99.9);
  }

  Future<void> _saveToGallery() async {
    try {
      await Gal.putVideo(widget.outputPath, album: 'فشرده‌سازی ویدئو');
      if (!mounted) return;
      setState(() => _savedToGallery = true);
      _toast('در گالری ذخیره شد');
    } on GalException catch (e) {
      if (!mounted) return;
      _toast(e.type == GalExceptionType.accessDenied
          ? 'برای ذخیره در گالری به اجازه دسترسی نیاز است'
          : 'ذخیره در گالری ناموفق بود');
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(widget.outputPath)]),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف فایل خروجی؟', style: TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final f = File(widget.outputPath);
      if (await f.exists()) await f.delete();
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _preview() async {
    await showDialog(
      context: context,
      builder: (_) => _VideoPreviewDialog(path: widget.outputPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نتیجه'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(36),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.success.withAlpha(128)),
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 46),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('ویدئو با موفقیت فشرده شد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'در ${Fmt.duration(widget.elapsed)} انجام شد',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 22),
          _comparisonCard(),
          const SizedBox(height: 18),
          _actionsGrid(),
          const SizedBox(height: 18),
          GradientButton(
            label: _savedToGallery ? 'ذخیره شد ✓' : 'ذخیره در گالری',
            icon: _savedToGallery
                ? Icons.check_rounded
                : Icons.download_rounded,
            onPressed: _savedToGallery ? null : _saveToGallery,
          ),
          const SizedBox(height: 12),
          OutlineButtonX(
            label: 'فشرده‌سازی ویدئوی دیگر',
            icon: Icons.add_rounded,
            color: AppColors.tealLight,
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppStyles.card(radius: 14),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.outputPath.split('/').last,
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.teal.withAlpha(115)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _column('قبل', Fmt.size(widget.info.sizeBytes),
                    Fmt.fa(widget.info.resolutionLabel), AppColors.textSecondary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(41),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${Fmt.percent(_savingPercent)} کمتر',
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: _column(
                  'بعد',
                  Fmt.size(widget.outputBytes),
                  Fmt.fa(Dimensions.compute(
                          widget.info, widget.options.effectiveShortSide)
                      .toString()),
                  AppColors.tealLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: widget.info.sizeBytes == 0
                  ? 0
                  : (widget.outputBytes / widget.info.sizeBytes)
                      .clamp(0.02, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.stroke,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.tealLight),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${Fmt.size(widget.info.sizeBytes - widget.outputBytes)} فضا آزاد شد',
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _column(String title, String value, String sub, Color color) {
    return Column(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(sub,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _actionsGrid() {
    final actions = [
      (_ActionData(Icons.play_arrow_rounded, 'پخش', _preview)),
      (_ActionData(Icons.share_rounded, 'اشتراک', _share)),
      (_ActionData(Icons.delete_outline_rounded, 'حذف', _delete)),
    ];
    return Row(
      children: actions
          .map((a) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: a.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: AppStyles.card(radius: 16),
                        child: Column(
                          children: [
                            Icon(a.icon,
                                color: AppColors.tealLight, size: 24),
                            const SizedBox(height: 6),
                            Text(a.label,
                                style: const TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _ActionData(this.icon, this.label, this.onTap);
}

class _VideoPreviewDialog extends StatefulWidget {
  final String path;
  const _VideoPreviewDialog({required this.path});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.file(File(widget.path));
    c.initialize().then((_) {
      if (mounted) {
        setState(() => _controller = c);
        c.play();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: AspectRatio(
        aspectRatio: c?.value.aspectRatio ?? 16 / 9,
        child: c == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.tealLight))
            : Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(c),
                  VideoProgressIndicator(c, allowScrubbing: true),
                  Center(
                    child: IconButton(
                      iconSize: 54,
                      icon: Icon(
                        c.value.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () => setState(() {
                        c.value.isPlaying ? c.pause() : c.play();
                      }),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
