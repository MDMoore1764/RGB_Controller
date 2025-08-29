import 'package:flutter/material.dart';
import 'package:frame_control/screens/presets/preset.dart';
import 'package:frame_control/utilities/light_animation_type.dart';
import 'package:frame_control/utilities/rainbow_mode_utilities.dart';
import 'package:provider/provider.dart';
import 'package:frame_control/app_state.dart';

class PresetsScreen extends StatefulWidget {
  PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? animationController;
  Color rainbowColor = Colors.red;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000),
    )..repeat();

    animationController!.addListener(() {
      setState(() {
        rainbowColor = calculateCurrentRainbowColor(
          animationController!.value,
          0.5,
        );
      });
    });
  }

  void _showAddPresetModal(BuildContext context, AppState appState) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String name = "";
        final TextEditingController nameController = TextEditingController();

        return Consumer<AppState>(
          builder: (context, value, child) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                nameController.addListener(() {
                  setDialogState(() {
                    name = nameController.text.trim();
                  });
                });

                return AlertDialog(
                  title: const Text('Add Preset'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Preset Name',
                          hintText: 'Enter preset name',
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      _PresetPreview(
                        color: appState.selectedColor,
                        pattern: appState.animationType,
                        rainbowMode: appState.rainbowMode,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: name.isEmpty
                          ? null
                          : () {
                              appState.addPreset(name);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Preset "$name" added!'),
                                ),
                              );
                              setDialogState(() {
                                name = "";
                              });
                            },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Presets',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddPresetModal(context, appState),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Preset'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: appState.presets.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No presets yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create your first preset by tapping "Add Preset"',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 2,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: appState.presets.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final preset = appState.presets[index];
                          return _PresetListItem(
                            preset: preset,
                            rainbowModeColor: rainbowColor,
                            active: preset.id == appState.activePreset,
                            onApply: () => appState.applyPreset(preset),
                            onDelete: () => _showDeleteConfirmation(
                              context,
                              appState,
                              preset,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppState appState,
    Preset preset,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Preset'),
          content: Text('Are you sure you want to delete "${preset.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                appState.removePreset(preset.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Preset "${preset.name}" deleted')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    animationController?.dispose();
    super.dispose();
  }
}

class _PresetListItem extends StatelessWidget {
  final Preset preset;
  final VoidCallback onApply;
  final VoidCallback onDelete;
  final bool active;
  final Color rainbowModeColor;

  const _PresetListItem({
    required this.preset,
    required this.onApply,
    required this.onDelete,
    required this.active,
    required this.rainbowModeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: active ? Theme.of(context).focusColor : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        onTap: onApply,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: preset.rainbowMode ? this.rainbowModeColor : preset.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withAlpha(100)),
          ),
        ),
        title: Text(
          preset.name.replaceFirst('.', preset.name[0].toUpperCase()),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pattern: ${preset.pattern.name}'),
            Row(
              children: [
                Text('Rainbow Mode: '),
                Icon(
                  preset.rainbowMode ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: preset.rainbowMode ? Colors.green : Colors.red,
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete),
              color: Colors.red,
              tooltip: 'Delete Preset',
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetPreview extends StatelessWidget {
  final Color color;
  final LightAnimationType pattern;
  final bool rainbowMode;

  const _PresetPreview({
    required this.color,
    required this.pattern,
    required this.rainbowMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Color:'),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Pattern: ${pattern.name}'),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Rainbow Mode: '),
              Icon(
                rainbowMode ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: rainbowMode ? Colors.green : Colors.red,
              ),
              Text(rainbowMode ? ' On' : ' Off'),
            ],
          ),
        ],
      ),
    );
  }
}
