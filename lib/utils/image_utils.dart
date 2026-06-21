import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

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

class ImageUtils {
  static Future<String> addWatermark({
    required String imagePath,
    required WatermarkData data,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final originalImage = await _decodeImage(bytes);
    if (originalImage == null) {
      throw Exception('无法读取图片');
    }

    final scale = originalImage.width / 1080.0;

    final watermarkOverlay = await _createWatermarkOverlay(
      imageWidth: originalImage.width,
      imageHeight: originalImage.height,
      data: data,
      scale: scale,
    );

    final result = await _compositeImages(originalImage, watermarkOverlay);

    final directory = await getTemporaryDirectory();
    final outputPath = '${directory.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(outputPath);
    await file.writeAsBytes(result);

    return outputPath;
  }

  static Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<Uint8List> _createWatermarkOverlay({
    required int imageWidth,
    required int imageHeight,
    required WatermarkData data,
    required double scale,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final padding = (36 * scale).toDouble();
    final bottomPadding = (50 * scale).toDouble();

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

    double currentY = imageHeight - bottomPadding - totalHeight;

    void drawTextWithShadow({
      required String text,
      required double x,
      required double y,
      required double fontSize,
      ui.Color color = const ui.Color(0xFFFFFFFF),
    }) {
      final scaledShadowBlur = 4.0 * scale;
      final scaledShadowOffset = 2.0 * scale;

      for (int i = 3; i >= 1; i--) {
        final shadowPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: fontSize,
              color: ui.Color.fromARGB((40 * i).clamp(0, 255), 0, 0, 0),
              fontWeight: FontWeight.normal,
              height: 1.2,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();

        shadowPainter.paint(
          canvas,
          Offset(x + scaledShadowOffset * i * 0.3, y + scaledShadowOffset * i * 0.3),
        );
      }

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
        textDirection: ui.TextDirection.ltr,
      )..layout();

      painter.paint(canvas, Offset(x, y));
    }

    if (data.showTime) {
      drawTextWithShadow(text: data.timeStr, x: padding, y: currentY, fontSize: timeFontSize);
      currentY += timeFontSize + lineSpacing;
      drawTextWithShadow(text: data.dateStr, x: padding, y: currentY, fontSize: normalFontSize);
      currentY += normalFontSize + lineSpacing;
    }

    if (data.showLocation && data.locationText.isNotEmpty) {
      drawTextWithShadow(text: data.locationText, x: padding, y: currentY, fontSize: normalFontSize);
      currentY += normalFontSize + lineSpacing;
    }

    if (data.showCustom && data.customText.isNotEmpty) {
      drawTextWithShadow(text: data.customText, x: padding, y: currentY, fontSize: normalFontSize);
      currentY += normalFontSize + lineSpacing;
    }

    if (data.showBrand) {
      final brandFontSize = smallFontSize;
      final pillHeight = (36 * scale).toDouble();
      final pillPaddingH = (16 * scale).toDouble();

      final brandPainter = TextPainter(
        text: TextSpan(
          text: data.brandText,
          style: TextStyle(fontSize: brandFontSize, color: const ui.Color(0xFFFFFFFF)),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final pillWidth = brandPainter.width + pillPaddingH * 2 + (24 * scale);

      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, currentY, pillWidth, pillHeight),
        Radius.circular(pillHeight / 2),
      );

      final bgPaint = Paint()
        ..color = const ui.Color(0xE6333333)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(pillRect, bgPaint);

      brandPainter.paint(
        canvas,
        Offset(padding + pillPaddingH + (24 * scale), currentY + (pillHeight - brandFontSize) / 2),
      );

      final iconCenterX = padding + pillPaddingH / 2 + (12 * scale);
      final iconCenterY = currentY + pillHeight / 2;
      final iconRadius = (8 * scale).toDouble();

      final iconPaint = Paint()
        ..color = const ui.Color(0xFF4CAF50)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(iconCenterX, iconCenterY), iconRadius, iconPaint);

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

    if (data.showBrand) {
      final faintPainter = TextPainter(
        text: TextSpan(
          text: data.brandText,
          style: TextStyle(fontSize: (18 * scale).toDouble(), color: const ui.Color(0x40FFFFFF)),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      faintPainter.paint(
        canvas,
        Offset(imageWidth - faintPainter.width - (24 * scale), imageHeight - faintPainter.height - (24 * scale)),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(imageWidth, imageHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<Uint8List> _compositeImages(ui.Image background, Uint8List overlayBytes) async {
    final overlayImage = await _decodeImage(overlayBytes);
    if (overlayImage == null) {
      throw Exception('水印层渲染失败');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(background, Offset.zero, Paint());
    canvas.drawImage(overlayImage, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(background.width, background.height);
    final byteData = await resultImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
