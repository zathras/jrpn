import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:jrpn/v/main_screen.dart';

late final ScalableImage jupiter;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  jupiter = await ScalableImage.fromSIAsset(
      rootBundle, 'packages/jrpn/assets/jupiter.si');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'make_icons',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'make_icons'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  initState() {
    super.initState();
    unawaited(makeIcons());
  }

  Future<void> makeIcons() async {
    const base = '/Users/billf/github/jrpn';
    // ignore: avoid_print
    print('cwd is ${File(".").absolute}');
    for (final model in ['15', '16']) {
      // https://developer.android.com/distribute/google-play/resources/icon-design-specifications
      await makeIcon(File('$base/jrpn$model/assets_$model/icon_adaptive.png'),
          size: 512, border: 92, modelName: '${model}C', adaptive: true);
      await makeIcon(File('$base/jrpn$model/assets_$model/icon_ios.png'),
          size: 1024, border: 72, modelName: '${model}C', adaptive: false);
    }
  }

  Future<void> makeIcon(File out,
      {required int size,
      required int border,
      required String modelName,
      required bool adaptive}) async {
    final recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder);
    if (!adaptive) {
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      c.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), paint);
    }
    final p = JrpnLogoPainter(jupiter, modelName, adaptive: adaptive);
    c.translate(border.toDouble(), border.toDouble());
    p.paint(
        c, Size(size.toDouble() - 2 * border, size.toDouble() - 2 * border));
    final ui.Picture pict = recorder.endRecording();
    final ui.Image rendered = await pict.toImage(size, size);
    final ByteData? bd =
        await rendered.toByteData(format: ui.ImageByteFormat.png);
    final bytes = Uint8List.fromList(bd!.buffer.asUint8List());
    await out.writeAsBytes(bytes);
    // ignore: avoid_print
    print('Created $out');
  }

  /*
  final im = await getImage(const Text('Hello, world'));
  final png = await im.toByteData(format: ui.ImageByteFormat.png);
  im.dispose();
  final f = File('/tmp/foo.png');
  await f.writeAsBytes(png!.buffer.asUint8List());
   */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Container(
            color: Colors.blue,
            child: Center(
              child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter:
                          JrpnLogoPainter(jupiter, '15C', adaptive: false))),
            )));
  }
}
