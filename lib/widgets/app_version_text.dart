import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionText extends StatelessWidget {
  final String prefix;
  final TextStyle? style;

  const AppVersionText({super.key, this.prefix = 'Versão ', this.style});

  static final Future<String> _version = PackageInfo.fromPlatform().then(
    (info) => '${info.version}+${info.buildNumber}',
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _version,
      builder: (context, snapshot) =>
          Text('$prefix${snapshot.data ?? ''}', style: style),
    );
  }
}
