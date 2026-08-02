import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A small, dependency-free device frame for checking responsive layouts while
/// running ClubUp on a desktop or in a browser.
///
/// Enable it with:
///
/// ```sh
/// flutter run -d chrome --dart-define=CLUBUP_DEVICE_PREVIEW=true
/// ```
///
/// It is deliberately debug-only. The preview is useful around the existing
/// app root because the [MediaQuery] override makes the application under test
/// lay out at the selected device dimensions.
class DevicePreview extends StatefulWidget {
  const DevicePreview({required this.child, this.enabled = false, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<DevicePreview> createState() => _DevicePreviewState();
}

class _DevicePreviewState extends State<DevicePreview> {
  static const _devices = <_PreviewDevice>[
    _PreviewDevice(
      id: 'iphone-15',
      label: 'iPhone 15',
      width: 393,
      height: 852,
      topInset: 59,
      bottomInset: 34,
      cornerRadius: 42,
      platform: TargetPlatform.iOS,
    ),
    _PreviewDevice(
      id: 'iphone-se',
      label: 'iPhone SE',
      width: 375,
      height: 667,
      topInset: 20,
      bottomInset: 0,
      cornerRadius: 32,
      platform: TargetPlatform.iOS,
    ),
    _PreviewDevice(
      id: 'pixel-9',
      label: 'Pixel 9',
      width: 412,
      height: 915,
      topInset: 24,
      bottomInset: 24,
      cornerRadius: 38,
      platform: TargetPlatform.android,
    ),
    _PreviewDevice(
      id: 'ipad-mini',
      label: 'iPad mini',
      width: 744,
      height: 1133,
      topInset: 24,
      bottomInset: 20,
      cornerRadius: 30,
      platform: TargetPlatform.iOS,
    ),
  ];

  int _selectedDeviceIndex = 0;
  bool _landscape = false;

  _PreviewDevice get _selectedDevice => _devices[_selectedDeviceIndex];

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !widget.enabled) return widget.child;

    final device = _landscape ? _selectedDevice.rotated : _selectedDevice;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Material(
        color: const Color(0xFF111214),
        child: Column(
          children: [
            _PreviewToolbar(
              devices: _devices,
              selectedIndex: _selectedDeviceIndex,
              landscape: _landscape,
              onDeviceChanged: (index) {
                setState(() => _selectedDeviceIndex = index);
              },
              onOrientationChanged: () {
                setState(() => _landscape = !_landscape);
              },
            ),
            Expanded(
              child: _PreviewStage(device: device, child: widget.child),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({
    required this.devices,
    required this.selectedIndex,
    required this.landscape,
    required this.onDeviceChanged,
    required this.onOrientationChanged,
  });

  final List<_PreviewDevice> devices;
  final int selectedIndex;
  final bool landscape;
  final ValueChanged<int> onDeviceChanged;
  final VoidCallback onOrientationChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1B1F),
        border: Border(bottom: BorderSide(color: Color(0xFF303238))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leading = <Widget>[
            const Icon(Icons.devices_other_rounded, color: Color(0xFFF04444)),
            const SizedBox(width: 10),
            const Text(
              'Device preview',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(width: 20),
          ];
          final selector = SizedBox(
            width: 154,
            child: DropdownButtonFormField<int>(
              initialValue: selectedIndex,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Device',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              items: [
                for (var index = 0; index < devices.length; index++)
                  DropdownMenuItem(
                    value: index,
                    child: Text(devices[index].label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onDeviceChanged(value);
              },
            ),
          );
          final orientation = OutlinedButton.icon(
            onPressed: onOrientationChanged,
            icon: Icon(
              landscape
                  ? Icons.stay_current_landscape
                  : Icons.stay_current_portrait,
              size: 18,
            ),
            label: Text(landscape ? 'Landscape' : 'Portrait'),
          );
          final status = <Widget>[
            const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF79D99A)),
            const SizedBox(width: 6),
            const Text(
              'Live preview  ·  press r to hot reload',
              style: TextStyle(color: Color(0xFFB7BAC4), fontSize: 12),
            ),
          ];

          final controls = <Widget>[
            ...leading,
            selector,
            const SizedBox(width: 10),
            orientation,
          ];
          if (constraints.maxWidth < 760) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [...controls, const SizedBox(width: 22), ...status],
              ),
            );
          }
          return Row(children: [...controls, const Spacer(), ...status]);
        },
      ),
    );
  }
}

class _PreviewStage extends StatelessWidget {
  const _PreviewStage({required this.device, required this.child});

  final _PreviewDevice device;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: device.width + 18,
          height: device.height + 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF050506),
              borderRadius: BorderRadius.circular(device.cornerRadius + 9),
              border: Border.all(color: const Color(0xFF454750), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 32,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(device.cornerRadius),
                child: SizedBox(
                  width: device.width,
                  height: device.height,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(device.width, device.height),
                      devicePixelRatio: 1,
                      padding: EdgeInsets.only(
                        top: device.topInset,
                        bottom: device.bottomInset,
                      ),
                      viewPadding: EdgeInsets.only(
                        top: device.topInset,
                        bottom: device.bottomInset,
                      ),
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child,
                        _DeviceCameraCutout(device: device),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceCameraCutout extends StatelessWidget {
  const _DeviceCameraCutout({required this.device});

  final _PreviewDevice device;

  @override
  Widget build(BuildContext context) {
    if (device.platform == TargetPlatform.android) {
      return const Positioned(
        top: 9,
        left: 0,
        right: 0,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF050506),
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 12, height: 12),
          ),
        ),
      );
    }
    if (device.width > 500) return const SizedBox.shrink();
    return const Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF050506),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: SizedBox(width: 88, height: 22),
        ),
      ),
    );
  }
}

class _PreviewDevice {
  const _PreviewDevice({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.topInset,
    required this.bottomInset,
    required this.cornerRadius,
    required this.platform,
  });

  final String id;
  final String label;
  final double width;
  final double height;
  final double topInset;
  final double bottomInset;
  final double cornerRadius;
  final TargetPlatform platform;

  _PreviewDevice get rotated => _PreviewDevice(
    id: id,
    label: label,
    width: height,
    height: width,
    topInset: bottomInset,
    bottomInset: topInset,
    cornerRadius: cornerRadius,
    platform: platform,
  );
}
