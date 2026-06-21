import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/image_utils.dart';

class PreviewScreen extends StatefulWidget {
  final String imagePath;

  const PreviewScreen({super.key, required this.imagePath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  DateTime _dateTime = DateTime.now();
  String _locationText = '';
  String _customText = '';
  bool _showTime = true;
  bool _showLocation = true;
  bool _showCustom = false;
  bool _showBrand = true;
  bool _isProcessing = false;
  String? _processedImagePath;

  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationText = '位置权限未开启');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _locationText =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      setState(() => _locationText = '定位中...');
    }
  }

  Future<void> _processImage() async {
    setState(() => _isProcessing = true);

    try {
      final data = WatermarkData(
        dateTime: _dateTime,
        locationText: _locationText,
        customText: _showCustom ? _customText : '',
        showTime: _showTime,
        showLocation: _showLocation,
        showCustom: _showCustom,
        showBrand: _showBrand,
      );

      final result = await ImageUtils.addWatermark(
        imagePath: widget.imagePath,
        data: data,
      );

      setState(() {
        _processedImagePath = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理失败: $e')),
        );
      }
    }
  }

  Future<void> _saveImage() async {
    if (_processedImagePath == null) {
      await _processImage();
    }

    if (_processedImagePath != null) {
      final directory = await getExternalStorageDirectory();
      final picturesDir = Directory('${directory!.path}/Pictures/WatermarkCamera');
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      final fileName =
          'watermark_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${picturesDir.path}/$fileName';

      await File(_processedImagePath!).copy(savedPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片已保存到相册')),
        );
      }
    }
  }

  Future<void> _shareImage() async {
    if (_processedImagePath == null) {
      await _processImage();
    }

    if (_processedImagePath != null) {
      await Share.shareXFiles(
        [XFile(_processedImagePath!)],
        text: '分享水印照片',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片预览
          Positioned.fill(
            child: Image.file(
              File(_processedImagePath ?? widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),

          // 顶部操作栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 返回按钮
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // 右侧操作
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.save, color: Colors.white),
                            onPressed: _isProcessing ? null : _saveImage,
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.white),
                            onPressed: _isProcessing ? null : _shareImage,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 底部设置面板
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 面板标题
                    const Row(
                      children: [
                        Icon(Icons.tune, color: Colors.white70, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '水印设置',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 水印内容开关
                    _buildSettingRow(
                      children: [
                        _buildToggleChip(
                          icon: Icons.access_time,
                          label: '时间',
                          selected: _showTime,
                          onTap: () => setState(() => _showTime = !_showTime),
                        ),
                        const SizedBox(width: 8),
                        _buildToggleChip(
                          icon: Icons.location_on,
                          label: '位置',
                          selected: _showLocation,
                          onTap: () =>
                              setState(() => _showLocation = !_showLocation),
                        ),
                        const SizedBox(width: 8),
                        _buildToggleChip(
                          icon: Icons.edit,
                          label: '备注',
                          selected: _showCustom,
                          onTap: () =>
                              setState(() => _showCustom = !_showCustom),
                        ),
                        const SizedBox(width: 8),
                        _buildToggleChip(
                          icon: Icons.verified,
                          label: '品牌',
                          selected: _showBrand,
                          onTap: () =>
                              setState(() => _showBrand = !_showBrand),
                        ),
                      ],
                    ),

                    // 自定义文字输入
                    if (_showCustom) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '输入备注信息（如：工作检查、现场记录等）',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.edit_note,
                              color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _customText = value);
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 操作按钮行
                    Row(
                      children: [
                        // 重新拍照
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('重拍'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 生成水印
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isProcessing ? null : _processImage,
                              icon: _isProcessing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle),
                              label: Text(
                                _isProcessing ? '处理中...' : '生成水印',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({required List<Widget> children}) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _buildToggleChip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blue.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.blue : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.blue : Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }
}
