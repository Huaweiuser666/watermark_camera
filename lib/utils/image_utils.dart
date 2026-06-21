import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// 水印数据模型
class WatermarkData {
  final DateTime dateTime;
  final String locationText;
  final String customText;
  final String brandText;
  final bool showTime;
  final bool showLocation;
  final bool showCustom;
  final bool showBrand;

  const WatermarkData({
    required this.dateTime,
    required this.locationText,
    required this.customText,
    this.brandText = '水印相机',
    this.showTime = true,
    this.showLocation = true,
    this.showCustom = false,
    this.showBrand = true,
  });

  String get timeStr => DateFormat('HH:mm').format(dateTime);
  String get dateStr => DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(dateTime);
}

/// 水印渲染工具 - 使用 Canvas 绘制，完美支持中文
class ImageUtils {
  /// 在图片上添加"今日水印相机"风格水印
  static Future<String> addWatermark({
    required String imagePath,
    required WatermarkData data,
  }) async {
    // 读取原图
    final bytes = await File(imagePath).readAsBytes();
    final originalImage = await _decodeImage(bytes);
    if (originalImage == null) {
      throw Exception('无法读取图片');
    }

    // 根据图片宽度计算缩放比例（以1080为基准）
    final scale = originalImage.width / 1080.0;

    // 创建水印覆盖层
    final watermarkOverlay = await _createWatermarkOverlay(
      imageWidth: originalImage.width,
      imageHeight: originalImage.height,
      data: data,
      scale: scale,
    );

    // 合成图片
    final result = await _compositeImages(originalImage, watermarkOverlay);

    // 保存结果
    final directory = await getTemporaryDirectory();
    final outputPath =
        '${directory.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(outputPath);
    await file.writeAsBytes(result);

    return outputPath;
  }

  /// 解码图片
  static Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// 创建水印覆盖层
  static Future<Uint8List> _createWatermarkOverlay({
    required int imageWidth,
    required int imageHeight,
    required WatermarkData data,
    required double scale,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 水印位置参数
    final padding = (36 * scale).toDouble();
    final bottomPadding = (50 * scale).toDouble();

    // 计算水印总高度
    double totalHeight = 0;
    final timeFontSize = (72 * scale).toDouble();
    final normalFontSize = (28 * scale).toDouble();
    final smallFontSize = (22 * scale).toDouble();
    final lineSpacing = (12 * scale).toDouble();

    if (data.showTime) {
      totalHeight += timeFontSize + lineSpacing;
      totalHeight += normalFontSize + lineSpacing;
    }
    if (data.showLocation) {
      totalHeight += normalFontSize + lineSpacing;
    }
    if (data.showCustom && data.customText.isNotEmpty) {
      totalHeight += normalFontSize + lineSpacing;
    }
    if (data.showBrand) {
      totalHeight += (36 * scale + 16 * scale);
    }

    // 水印起始 Y 坐标（从底部往上）
    double currentY = imageHeight - bottomPadding - totalHeight;

    // 绘制文字阴影的辅助函数
    void drawTextWithShadow({
      required String text,
      required double x,
      required double y,
      required double fontSize,
      ui.Color color = const ui.Color(0xFFFFFFFF),
      double shadowBlur = 4.0,
      double shadowOffset = 2.0,
    }) {
      final scaledShadowBlur = shadowBlur * scale;
      final scaledShadowOffset = shadowOffset * scale;

      // 绘制多层阴影增强可读性
      for (int i = 3; i >= 1; i--) {
        final shadowPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: fontSize,
              color: ui.Color.fromARGB(
                (40 * i).clamp(0, 255),
                0,
                0,
                0,
              ),
              fontWeight: FontWeight.normal,
              height: 1.2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        shadowPainter.paint(
          canvas,
          Offset(x + scaledShadowOffset * i * 0.3, y + scaledShadowOffset * i * 0.3),
        );
      }

      // 绘制主文字
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: FontWeight.normal,
            height: 1.2,
            shadows: [
              Shadow(
                color: ui.Color.fromARGB(80, 0, 0, 0),
                blurRadius: scaledShadowBlur,
                offset: Offset(scaledShadowOffset, scaledShadowOffset),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      painter.paint(canvas, Offset(x, y));
    }

    // 绘制时间（大号）
    if (data.showTime) {
      drawTextWithShadow(
        text: data.timeStr,
        x: padding,
        y: currentY,
        fontSize: timeFontSize,
      );
      currentY += timeFontSize + lineSpacing;

      // 绘制日期
      drawTextWithShadow(
        text: data.dateStr,
        x: padding,
        y: currentY,
        fontSize: normalFontSize,
      );
      currentY += normalFontSize + lineSpacing;
    }

    // 绘制位置
    if (data.showLocation && data.locationText.isNotEmpty) {
      drawTextWithShadow(
        text: data.locationText,
        x: padding,
        y: currentY,
        fontSize: normalFontSize,
      );
      currentY += normalFontSize + lineSpacing;
    }

    // 绘制自定义文字
    if (data.showCustom && data.customText.isNotEmpty) {
      drawTextWithShadow(
        text: data.customText,
        x: padding,
        y: currentY,
        fontSize: normalFontSize,
      );
      currentY += normalFontSize + lineSpacing;
    }

    // 绘制品牌标签（深色圆角药丸形状）
    if (data.showBrand) {
      final brandText = data.brandText;
      final brandFontSize = smallFontSize;
      final pillHeight = (36 * scale).toDouble();
      final pillPaddingH = (16 * scale).toDouble();

      // 测量品牌文字宽度
      final brandPainter = TextPainter(
        text: TextSpan(
          text: brandText,
          style: TextStyle(
            fontSize: brandFontSize,
            color: const ui.Color(0xFFFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final pillWidth = brandPainter.width + pillPaddingH * 2 + (24 * scale);

      // 绘制药丸背景
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, currentY, pillWidth, pillHeight),
        Radius.circular(pillHeight / 2),
      );

      final bgPaint = Paint()
        ..color = const ui.Color(0xE6333333)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(pillRect, bgPaint);

      // 绘制品牌文字
      brandPainter.paint(
        canvas,
        Offset(padding + pillPaddingH + (24 * scale), currentY + (pillHeight - brandFontSize) / 2),
      );

      // 绘制小勾图标（简单的圆圈+勾）
      final iconCenterX = padding + pillPaddingH / 2 + (12 * scale);
      final iconCenterY = currentY + pillHeight / 2;
      final iconRadius = (8 * scale).toDouble();

      final iconPaint = Paint()
        ..color = const ui.Color(0xFF4CAF50)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(iconCenterX, iconCenterY), iconRadius, iconPaint);

      // 勾号
      final checkPaint = Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..strokeWidth = (2 * scale)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final checkPath = Path();
      checkPath.moveTo(iconCenterX - (4 * scale), iconCenterY);
      checkPath.lineTo(iconCenterX - (1 * scale), iconCenterY + (3 * scale));
      checkPath.lineTo(iconCenterX + (4 * scale), iconCenterY - (3 * scale));
      canvas.drawPath(checkPath, checkPaint);
    }

    // 右下角绘制淡化品牌水印
    if (data.showBrand) {
      final faintPainter = TextPainter(
        text: TextSpan(
          text: data.brandText,
          style: TextStyle(
            fontSize: (18 * scale).toDouble(),
            color: const ui.Color(0x40FFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      faintPainter.paint(
        canvas,
        Offset(
          imageWidth - faintPainter.width - (24 * scale),
          imageHeight - faintPainter.height - (24 * scale),
        ),
      );
    }

    // 将 Canvas 转为图片
    final picture = recorder.endRecording();
    final imgWidth = imageWidth.toDouble();
    final imgHeight = imageHeight.toDouble();

    final image = await picture.toImage(imgWidth.toInt(), imgHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 合成两张图片
  static Future<Uint8List> _compositeImages(
    ui.Image background,
    Uint8List overlayBytes,
  ) async {
    final overlayImage = await _decodeImage(overlayBytes);
    if (overlayImage == null) {
      throw Exception('水印层渲染失败');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制背景图
    canvas.drawImage(background, Offset.zero, Paint());

    // 绘制水印覆盖层
    canvas.drawImage(overlayImage, Offset.zero, Paint());

    // 编码为 JPEG
    final picture = recorder.endRecording();
    final resultImage =
        await picture.toImage(background.width, background.height);
    final byteData =
        await resultImage.toByteData(format: ui.ImageByteFormat.rawRgba);

    // 转换为 PNG（无损）
    final pngByteData =
        await resultImage.toByteData(format: ui.ImageByteFormat.png);
    return pngByteData!.buffer.asUint8List();
  }
}
