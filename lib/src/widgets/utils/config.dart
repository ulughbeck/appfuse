import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

Future<void> selectConfigDialog(
  BuildContext context, {
  String title = 'Config',
}) async {
  final configs = context.fuse.state.configs;
  final selectedConfig = context.fuse.state.config;
  if (configs == null) return;
  if (selectedConfig is EmptyConfig) return;

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: configs
            .map(
              (config) => _ConfigRadioButton(
                selectedConfig: selectedConfig,
                config: config,
                onChanged: (config) {
                  if (config != null) context.changeConfig(config);
                  Navigator.of(context).pop();
                },
              ),
            )
            .toList(),
      ),
    ),
  );
}

@immutable
class _ConfigRadioButton extends StatelessWidget {
  const _ConfigRadioButton({
    required this.selectedConfig,
    required this.config,
    required this.onChanged,
  });
  final BaseConfig selectedConfig;
  final BaseConfig config;
  final ValueChanged<BaseConfig?> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(config.name),
        leading: Radio<String>(
          activeColor: config.color,
          value: config.name,
          groupValue: selectedConfig.name,
          onChanged: (value) {
            onChanged.call(config);
          },
        ),
        onTap: () => onChanged.call(config),
      );
}
