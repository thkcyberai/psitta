import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: const [
        ListTile(title: Text('Default Voice'), subtitle: Text('en-US-AriaNeural'),
          trailing: Icon(Icons.chevron_right)),
        ListTile(title: Text('Playback Speed'), subtitle: Text('1.0x'),
          trailing: Icon(Icons.chevron_right)),
        ListTile(title: Text('Auto-Delete Documents'), subtitle: Text('After 60 days'),
          trailing: Icon(Icons.chevron_right)),
      ]));
  }
}
