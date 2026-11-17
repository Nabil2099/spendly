import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Expressive poses for the **Spendi AI** assistant avatar.
enum SpendiPose { greeting, thinking, advising, happy }

/// Renders the **Spendi AI** SVG mascot in the requested [pose].
class SpendiAvatar extends StatelessWidget {
  const SpendiAvatar({
    super.key,
    this.pose = SpendiPose.advising,
    this.size = 48,
  });

  final SpendiPose pose;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svgForPose(pose), width: size, height: size);
  }

  static String _svgForPose(SpendiPose pose) {
    final eyesAndMouth = switch (pose) {
      SpendiPose.greeting =>
        '''
  <circle cx="47" cy="56" r="5.5" fill="#A8E6CF"/>
  <circle cx="73" cy="56" r="5.5" fill="#A8E6CF"/>
  <circle cx="48.5" cy="54.5" r="1.8" fill="#FFFFFF"/>
  <circle cx="74.5" cy="54.5" r="1.8" fill="#FFFFFF"/>
  <path d="M52 65C55 69 65 69 68 65" stroke="#A8E6CF" stroke-width="3" stroke-linecap="round"/>
''',
      SpendiPose.thinking =>
        '''
  <circle cx="49" cy="54" r="5" fill="#A8E6CF"/>
  <circle cx="75" cy="54" r="5" fill="#A8E6CF"/>
  <circle cx="50.5" cy="52.5" r="1.6" fill="#FFFFFF"/>
  <circle cx="76.5" cy="52.5" r="1.6" fill="#FFFFFF"/>
  <path d="M55 66H66" stroke="#A8E6CF" stroke-width="3" stroke-linecap="round"/>
  <circle cx="96" cy="24" r="3.2" fill="#E1B07E"/>
  <circle cx="104" cy="17" r="4.5" fill="#E1B07E"/>
''',
      SpendiPose.advising =>
        '''
  <circle cx="47" cy="57" r="5.2" fill="#A8E6CF"/>
  <circle cx="73" cy="57" r="5.2" fill="#A8E6CF"/>
  <circle cx="48.5" cy="55.5" r="1.8" fill="#FFFFFF"/>
  <circle cx="74.5" cy="55.5" r="1.8" fill="#FFFFFF"/>
  <path d="M53 65C55.5 68 64.5 68 67 65" stroke="#A8E6CF" stroke-width="3" stroke-linecap="round"/>
''',
      SpendiPose.happy =>
        '''
  <path d="M41 58C43 52 51 52 53 58" stroke="#A8E6CF" stroke-width="3.2" stroke-linecap="round"/>
  <path d="M67 58C69 52 77 52 79 58" stroke="#A8E6CF" stroke-width="3.2" stroke-linecap="round"/>
  <path d="M51 64C55 70 65 70 69 64" stroke="#A8E6CF" stroke-width="3.2" stroke-linecap="round"/>
  <path d="M22 28L24 32L28 34L24 36L22 40L20 36L16 34L20 32L22 28Z" fill="#E1B07E"/>
  <path d="M98 28L100 32L104 34L100 36L98 40L96 36L92 34L96 32L98 28Z" fill="#E1B07E"/>
''',
    };

    final extraHands = switch (pose) {
      SpendiPose.greeting => '<path d="M90 88C98 84 103 75 101 66" stroke="#0F7A5F" stroke-width="7" stroke-linecap="round"/><circle cx="101" cy="64" r="5" fill="#E1B07E"/>',
      SpendiPose.thinking => '<path d="M32 90C26 83 32 75 42 74" stroke="#0F7A5F" stroke-width="6.5" stroke-linecap="round"/><circle cx="43" cy="74" r="4.5" fill="#E1B07E"/>',
      SpendiPose.advising => '<path d="M88 92L102 82" stroke="#0F7A5F" stroke-width="6.5" stroke-linecap="round"/><circle cx="103" cy="81" r="4.5" fill="#E1B07E"/>',
      SpendiPose.happy => '<path d="M32 90C24 83 22 74 24 67" stroke="#0F7A5F" stroke-width="6.5" stroke-linecap="round"/><path d="M88 90C96 83 98 74 96 67" stroke="#0F7A5F" stroke-width="6.5" stroke-linecap="round"/>',
    };

    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" fill="none">
  <circle cx="60" cy="62" r="52" fill="#E4EFEA"/>
  <path d="M60 12V24" stroke="#4F6D8A" stroke-width="4" stroke-linecap="round"/>
  <path d="M60 4L62.8 10.2L69 13L62.8 15.8L60 22L57.2 15.8L51 13L57.2 10.2L60 4Z" fill="#E1B07E"/>
  <rect x="16" y="52" width="12" height="24" rx="6" fill="#4F6D8A"/>
  <rect x="92" y="52" width="12" height="24" rx="6" fill="#4F6D8A"/>
  <rect x="24" y="28" width="72" height="64" rx="26" fill="#0F7A5F"/>
  <rect x="33" y="42" width="54" height="32" rx="14" fill="#192A26"/>
  $eyesAndMouth
  <path d="M36 96C36 89.3726 41.3726 84 48 84H72C78.6274 84 84 89.3726 84 96V102H36V96Z" fill="#4F6D8A"/>
  <circle cx="60" cy="95" r="5" fill="#E1B07E"/>
  $extraHands
</svg>
''';
  }
}
