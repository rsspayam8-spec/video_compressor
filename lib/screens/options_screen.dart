import 'dart:io';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/compress_models.dart';
import '../services/ffmpeg_service.dart';
import '../widgets/common.dart';
import 'progress_screen.dart';

class OptionsScreen extends StatefulWidget {
  final MediaInfo info;
  const OptionsScreen({super.key, required this.info});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  late CompressOptions _options;
  String? _thumbPath;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final suggestedBitrate = widget.info.bitrate > 0
        ? (widget.info.bitrate / 1000 * 0.6).round().clamp(300, 8000)
        : 2000;
    _options = CompressOptions(
      preset: CompressPreset.all[1], // پیشنهادی
      customShortSide: widget.info.shortSide,
      customBitrateKbps: suggestedBitrate,
      customFps: widget.info.frameRate,
      targetSizeMb: (widget.info.sizeBytes / 1024 / 1024 / 3)
          .clamp(1, 500)
          .toDouble(),
    );
    _nameController.text = Fmt.safeName(widget.info.fileName);
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    final path = await FfmpegService.instance.generateThumbnail(widget.info);
    if (mounted) setState(() => _thumbPath = path);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _estimatedBytes => SizeEstimator.estimate(widget.info, _options);

  double get _savingPercent {
    final saved = widget.info.sizeBytes - _estimatedBytes;
    if (widget.info.sizeBytes <= 0) return 0;
    return (saved / widget.info.sizeBytes * 100).clamp(0.0, 99.0);
  }

  Dimensions get _outputDims =>
      Dimensions.compute(widget.info, _options.effectiveShortSide);

  Future<void> _start() async {
    final options = _options.copyWith(outputName: _nameController.text);
    final outputPath =
        await FfmpegService.instance.buildOutputPath(widget.info, options);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressScreen(
          info: widget.info,
          options: options,
          outputPath: outputPath,
          estimatedBytes: _estimatedBytes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیم فشرده‌سازی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _previewCard(),
          const SizedBox(height: 16),
          _resultPreviewBar(),
          const SectionTitle(title: 'میزان فشرده‌سازی'),
          ...CompressPreset.all.map(_presetCard),
          const SectionTitle(title: 'تنظیمات خروجی'),
          _outputSettings(),
          const SizedBox(height: 22),
          GradientButton(
            label: 'شروع فشرده‌سازی',
            icon: Icons.play_arrow_rounded,
            onPressed: _start,
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'با تراشه سخت‌افزاری گوشی پردازش می‌شود — سریع و کم‌مصرف',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  Widget _previewCard() {
    return Container(
      decoration: AppStyles.card(radius: 20),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 108,
              height: 76,
              child: _thumbPath != null
                  ? Image.file(File(_thumbPath!), fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surfaceHigh,
                      child: const Icon(Icons.movie_rounded,
                          color: AppColors.textSecondary),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.info.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    InfoChip(
                        icon: Icons.aspect_ratio_rounded,
                        label: Fmt.fa(widget.info.resolutionLabel)),
                    InfoChip(
                        icon: Icons.sd_storage_rounded,
                        label: Fmt.size(widget.info.sizeBytes)),
                    InfoChip(
                        icon: Icons.schedule_rounded,
                        label: Fmt.duration(widget.info.duration)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// نوار تخمین نتیجه — مهم‌ترین بخش UX
  Widget _resultPreviewBar() {
    final saving = _savingPercent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withAlpha(128)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _estimateColumn(
                  'حجم فعلی',
                  Fmt.size(widget.info.sizeBytes),
                  Fmt.fa(widget.info.resolutionLabel),
                  AppColors.textSecondary,
                ),
              ),
              Column(
                children: [
                  Icon(Icons.arrow_back_rounded,
                      color: AppColors.tealLight.withAlpha(230), size: 22),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.percent(saving)}−',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Expanded(
                child: _estimateColumn(
                  'حجم تقریبی خروجی',
                  Fmt.size(_estimatedBytes),
                  Fmt.fa(_outputDims.toString()),
                  AppColors.tealLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (1 - saving / 100).clamp(0.02, 1.0).toDouble(),
              minHeight: 7,
              backgroundColor: AppColors.stroke,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.tealLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimateColumn(
      String title, String value, String sub, Color color) {
    return Column(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(sub,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ------------------------------------------------------------------
  Widget _presetCard(CompressPreset preset) {
    final selected = _options.preset.kind == preset.kind;
    final previewOptions = _options.copyWith(preset: preset);
    final estimate = SizeEstimator.estimate(widget.info, previewOptions);
    final dims = Dimensions.compute(widget.info, previewOptions.effectiveShortSide);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _options = _options.copyWith(preset: preset)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: selected
                ? AppStyles.selectedCard(radius: 18)
                : AppStyles.card(radius: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    _radio(selected),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preset.title,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(preset.subtitle,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.5)),
                        ],
                      ),
                    ),
                    if (preset.kind != PresetKind.custom &&
                        preset.kind != PresetKind.targetSize)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Fmt.size(estimate),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppColors.tealLight
                                      : AppColors.textPrimary)),
                          Text(Fmt.fa(dims.toString()),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                  ],
                ),
                if (selected && preset.kind == PresetKind.targetSize)
                  _targetSizeControls(),
                if (selected && preset.kind == PresetKind.custom)
                  _customControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _radio(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.teal : AppColors.stroke,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                    color: AppColors.teal, shape: BoxShape.circle),
              ),
            )
          : null,
    );
  }

  Widget _targetSizeControls() {
    final maxMb = (widget.info.sizeBytes / 1024 / 1024).clamp(2, 2000).toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('حجم هدف', style: TextStyle(fontSize: 13.5)),
              const Spacer(),
              Text(
                '${Fmt.num_(_options.targetSizeMb, decimals: 1)} مگابایت',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealLight),
              ),
            ],
          ),
          Slider(
            value: _options.targetSizeMb.clamp(1, maxMb).toDouble(),
            min: 1,
            max: maxMb,
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(targetSizeMb: v)),
          ),
          Wrap(
            spacing: 8,
            children: [8.0, 16.0, 25.0, 50.0]
                .where((v) => v < maxMb)
                .map((v) => ActionChip(
                      label: Text('${Fmt.num_(v)} م.ب',
                          style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.stroke),
                      onPressed: () => setState(
                          () => _options = _options.copyWith(targetSizeMb: v)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// کنترل بیت‌ریت دستی — هرچه این عدد بیشتر، کیفیت بالاتر ولی حجم هم بیشتر
  Widget _customControls() {
    final resolutions = <int>{240, 360, 480, 540, 720, 1080, 1440, widget.info.shortSide}
        .where((r) => r <= widget.info.shortSide)
        .toList()
      ..sort();

    final bitrate = _options.customBitrateKbps ?? 2000;
    final previewOptions = _options.copyWith(preset: CompressPreset.all[5]);
    final estimate = SizeEstimator.estimate(widget.info, previewOptions);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text('رزولوشن', style: TextStyle(fontSize: 13.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: resolutions.map((r) {
              final active = _options.customShortSide == r;
              return ChoiceChip(
                label: Text(Fmt.fa('${r}p'),
                    style: const TextStyle(fontSize: 12.5)),
                selected: active,
                selectedColor: AppColors.teal,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                    color: active ? AppColors.teal : AppColors.stroke),
                labelStyle: TextStyle(
                    color: active ? Colors.white : AppColors.textSecondary),
                onSelected: (_) => setState(
                    () => _options = _options.copyWith(customShortSide: r)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('بیت‌ریت ویدئو', style: TextStyle(fontSize: 13.5)),
              const Spacer(),
              Text('${Fmt.fa(bitrate.toString())} kbps',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.tealLight,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: bitrate.toDouble().clamp(200, 20000),
            min: 200,
            max: 20000,
            divisions: 198,
            onChanged: (v) => setState(() => _options =
                _options.copyWith(customBitrateKbps: (v / 100).round() * 100)),
          ),
          Wrap(
            spacing: 8,
            children: [500, 1000, 2000, 4000, 8000]
                .map((v) => ActionChip(
                      label: Text('${Fmt.fa(v.toString())} kbps',
                          style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.stroke),
                      onPressed: () => setState(() =>
                          _options = _options.copyWith(customBitrateKbps: v)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('حجم تقریبی خروجی: ${Fmt.size(estimate)}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('فریم بر ثانیه', style: TextStyle(fontSize: 13.5)),
              const Spacer(),
              Text(Fmt.num_(_options.customFps ?? widget.info.frameRate, decimals: 0),
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.tealLight,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: (_options.customFps ?? widget.info.frameRate)
                .clamp(15, widget.info.frameRate)
                .toDouble(),
            min: 15,
            max: widget.info.frameRate.clamp(16, 120).toDouble(),
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(customFps: v)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  Widget _outputSettings() {
    return Container(
      decoration: AppStyles.card(radius: 18),
      child: Column(
        children: [
          SettingRow(
            icon: Icons.memory_rounded,
            title: 'کدک',
            value: _options.codec == VideoCodec.h264 ? 'H.264' : 'H.265',
            onTap: _pickCodec,
          ),
          const Divider(height: 1),
          SettingRow(
            icon: Icons.video_file_rounded,
            title: 'فرمت خروجی',
            value: _options.format.label,
            onTap: _pickFormat,
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: _options.removeAudio,
            onChanged: widget.info.hasAudio
                ? (v) => setState(
                    () => _options = _options.copyWith(removeAudio: v))
                : null,
            activeThumbColor: AppColors.teal,
            title: const Text('حذف صدا', style: TextStyle(fontSize: 14.5)),
            subtitle: Text(
              widget.info.hasAudio
                  ? 'حجم را بیشتر کم می‌کند'
                  : 'این ویدئو صدا ندارد',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            secondary: const Icon(Icons.volume_off_rounded,
                size: 20, color: AppColors.tealLight),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'نام فایل خروجی',
                labelStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded,
                    size: 20, color: AppColors.tealLight),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.stroke),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCodec() => _showSheet<VideoCodec>(
        title: 'کدک ویدئو',
        items: VideoCodec.values,
        current: _options.codec,
        labelOf: (c) => c.label,
        hintOf: (c) => c.hint,
        onSelect: (c) => setState(() => _options = _options.copyWith(codec: c)),
      );

  Future<void> _pickFormat() => _showSheet<OutputFormat>(
        title: 'فرمت خروجی',
        items: OutputFormat.values,
        current: _options.format,
        labelOf: (f) => f.label,
        hintOf: (f) => f == OutputFormat.mp4
            ? 'پیشنهادی — سازگار با همه دستگاه‌ها'
            : f == OutputFormat.mkv
                ? 'مناسب فایل‌های بزرگ'
                : 'سازگار با دستگاه‌های اپل',
        onSelect: (f) => setState(() => _options = _options.copyWith(format: f)),
      );

  Future<void> _showSheet<T>({
    required String title,
    required List<T> items,
    required T current,
    required String Function(T) labelOf,
    required String Function(T) hintOf,
    required void Function(T) onSelect,
  }) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.map((item) {
              final selected = item == current;
              return ListTile(
                onTap: () {
                  onSelect(item);
                  Navigator.pop(context);
                },
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.teal : AppColors.textSecondary,
                ),
                title: Text(labelOf(item),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600)),
                subtitle: Text(hintOf(item),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
