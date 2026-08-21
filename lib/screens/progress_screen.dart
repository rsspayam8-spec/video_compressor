import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/compress_models.dart';
import '../services/ffmpeg_service.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

class ProgressScreen extends StatefulWidget {
  final MediaInfo info;
  final CompressOptions options;
  final String outputPath;
  final int estimatedBytes;

  const ProgressScreen({
    super.key,
    required this.info,
    required this.options,
    required this.outputPath,
    required this.estimatedBytes,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  CompressProgress _progress = const CompressProgress(
      percent: 0, processed: Duration.zero, elapsed: Duration.zero);
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _run();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _run() async {
    final result = await FfmpegService.instance.compress(
      info: widget.info,
      options: widget.options,
      outputPath: widget.outputPath,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    _finished = true;

    if (result.cancelled) {
      Navigator.pop(context);
      return;
    }
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'خطای نامشخص')),
      );
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          info: widget.info,
          options: widget.options,
          outputPath: result.outputPath!,
          outputBytes: result.outputBytes,
          elapsed: _progress.elapsed,
        ),
      ),
    );
  }

  Future<bool> _confirmCancel() async {
    if (_finished) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('لغو پردازش؟', style: TextStyle(fontSize: 17)),
        content: const Text(
          'اگر الان لغو کنید، فایل خروجی ساخته نمی‌شود.',
          style: TextStyle(fontSize: 13.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ادامه بده',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('لغو کن',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FfmpegService.instance.cancel();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmCancel();
        if (ok && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _circle(),
                const SizedBox(height: 34),
                const Text('در حال فشرده‌سازی…',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  _progress.remaining != null && _progress.percent > 3
                      ? 'زمان باقی‌مانده حدود ${Fmt.duration(_progress.remaining!)}'
                      : 'در حال آماده‌سازی…',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const Spacer(),
                _statsRow(),
                const SizedBox(height: 22),
                OutlineButtonX(
                  label: 'لغو',
                  icon: Icons.close_rounded,
                  color: AppColors.danger,
                  onPressed: () async {
                    final ok = await _confirmCancel();
                    if (ok && mounted) Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'برای سرعت بیشتر، برنامه را در پس‌زمینه نبرید',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle() {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 210,
            height: 210,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 12,
              color: AppColors.stroke,
            ),
          ),
          SizedBox(
            width: 210,
            height: 210,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _progress.percent / 100),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, _) => CircularProgressIndicator(
                value: math.max(value, 0.01),
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                color: AppColors.tealLight,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.percent(_progress.percent),
                style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealLight),
              ),
              const SizedBox(height: 2),
              Text(
                '${Fmt.duration(_progress.processed)} از ${Fmt.duration(widget.info.duration)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: AppStyles.card(radius: 18),
      child: Row(
        children: [
          _stat('زمان سپری‌شده', Fmt.duration(_progress.elapsed)),
          _divider(),
          _stat('حجم تقریبی', Fmt.size(widget.estimatedBytes)),
          _divider(),
          _stat('سرعت',
              '${Fmt.num_(_progress.speed, decimals: 1)}×'),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.stroke);

  Widget _stat(String title, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
