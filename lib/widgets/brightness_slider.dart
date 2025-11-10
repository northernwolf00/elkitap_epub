import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


class BrightnessSlider extends StatefulWidget {
  final Color fontColor;
  final Color backColor;
  final double brightnessLevel;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double>? onChangeEnd; 

  const BrightnessSlider({
    super.key,
    required this.fontColor,
    required this.backColor,
    required this.brightnessLevel,
    required this.onBrightnessChanged,
    this.onChangeEnd,
  });

  @override
  _BrightnessSliderState createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<BrightnessSlider> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.brightnessLevel;
  }

  @override
  void didUpdateWidget(covariant BrightnessSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent changed brightness, keep the local value in sync.
    if (oldWidget.brightnessLevel != widget.brightnessLevel) {
      _localValue = widget.brightnessLevel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20.h, left: 10.w, right: 10.w),
      decoration: BoxDecoration(
        color: widget.backColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 15.w),
            child: Container(
              height: 18,
              width: 18,
              decoration: BoxDecoration(
                border: Border.all(color: widget.fontColor, width: 2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 24.0,
                activeTrackColor: Colors.grey.shade600,
                inactiveTrackColor: Colors.grey.shade300,
                // Give the thumb a non-zero radius so it is draggable,
                // but keep it visually transparent.
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                thumbColor: Colors.transparent, // visually invisible
                overlayColor: Colors.transparent,
              ),
              child: Slider(
                value: _localValue.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  // update local state so slider moves immediately
                  setState(() {
                    _localValue = value;
                  });
                  // notify parent immediately (so parent can reflect change in UI)
                  widget.onBrightnessChanged(value);
                },
                onChangeEnd: (value) {
                  // parent can perform async brightness setting here
                  if (widget.onChangeEnd != null) {
                    widget.onChangeEnd!(value);
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 15.w),
            child: Icon(Icons.wb_sunny_outlined, size: 25.sp, color: widget.fontColor),
          ),
        ],
      ),
    );
  }
}

