import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../widget_marker_google_map.dart';

class MarkerGenerator extends StatefulWidget {
  const MarkerGenerator({
    Key? key,
    required this.widgetMarkers,
    required this.onMarkerGenerated,
  }) : super(key: key);
  final List<WidgetMarker> widgetMarkers;
  final ValueChanged<List<Marker>> onMarkerGenerated;

  @override
  _MarkerGeneratorState createState() => _MarkerGeneratorState();
}

class _MarkerGeneratorState extends State<MarkerGenerator> {
  List<GlobalKey> globalKeys = [];
  List<WidgetMarker> lastMarkers = [];

  List<GlobalKey> getGlobalKeys() {
    return widget.widgetMarkers.map((_) => GlobalKey()).toList();
  }

  Future<void> _waitForRepaint(GlobalKey key) async {
    while (true) {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is RenderRepaintBoundary &&
          renderObject.debugNeedsPaint == false) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<Marker> _convertToMarker(GlobalKey key) async {
    final keyIndex = globalKeys.indexOf(key);
    if (keyIndex == -1) {
      debugPrint('Key not found in globalKeys. Key: $key');
      throw FlutterError('Key not found in globalKeys list.');
    }

    await _waitForRepaint(key);

    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject == null || renderObject is! RenderRepaintBoundary) {
      throw FlutterError(
          'RenderRepaintBoundary not found for the provided key.');
    }

    RenderRepaintBoundary boundary = renderObject;

    final image = await boundary.toImage(pixelRatio: 2);
    final byteData =
        await image.toByteData(format: ImageByteFormat.png) ?? ByteData(0);
    final uint8List = byteData.buffer.asUint8List();

    final widgetMarker = widget.widgetMarkers[keyIndex];
    return Marker(
      onTap: widgetMarker.onTap,
      markerId: MarkerId(widgetMarker.markerId),
      position: widgetMarker.position,
      icon: BitmapDescriptor.fromBytes(uint8List),
      draggable: widgetMarker.draggable,
      infoWindow: widgetMarker.infoWindow,
      rotation: widgetMarker.rotation,
      visible: widgetMarker.visible,
      zIndex: widgetMarker.zIndex,
      onDragStart: widgetMarker.onDragStart,
      onDragEnd: widgetMarker.onDragEnd,
      onDrag: widgetMarker.onDrag,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => onBuildCompleted());
  }

  Future<void> onBuildCompleted() async {
    /// Skip when there's no change in widgetMarkers.
    if (lastMarkers == widget.widgetMarkers) {
      return;
    }
    lastMarkers = widget.widgetMarkers;
    final markers =
        await Future.wait(globalKeys.map((key) => _convertToMarker(key)));
    widget.onMarkerGenerated.call(markers);
  }

  @override
  Widget build(BuildContext context) {
    globalKeys = getGlobalKeys(); // 常に最新の globalKeys を生成
    return Transform.translate(
      offset: Offset(
        -MediaQuery.of(context).size.width,
        -MediaQuery.of(context).size.height,
      ),
      child: Stack(
        children: widget.widgetMarkers.map(
          (widgetMarker) {
            final key = globalKeys[widget.widgetMarkers.indexOf(widgetMarker)];
            return RepaintBoundary(
              key: key,
              child: widgetMarker.widget,
            );
          },
        ).toList(),
      ),
    );
  }
}
