import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rivulet/features/downloads/services/file_system_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ConfigureDownloadDirectoryDialog extends ConsumerStatefulWidget {
  const ConfigureDownloadDirectoryDialog({super.key});

  @override
  ConsumerState<ConfigureDownloadDirectoryDialog> createState() =>
      _ConfigureDownloadDirectoryDialogState();
}

class _ConfigureDownloadDirectoryDialogState
    extends ConsumerState<ConfigureDownloadDirectoryDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
  }

  Future<void> _loadCurrentPath() async {
    final fs = ref.read(fileSystemServiceProvider);
    final customPath = await fs.getCustomDownloadPath();

    if (customPath != null) {
      _controller.text = customPath;
    } else {
      // Default path
      final appDocDir = await getApplicationDocumentsDirectory();
      _controller.text = p.join(appDocDir.path, 'downloads');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDirectory() async {
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath();

    if (selectedDirectory != null) {
      _controller.text = selectedDirectory;
    }
  }

  Future<void> _save() async {
    final fs = ref.read(fileSystemServiceProvider);
    await fs.setCustomDownloadPath(_controller.text);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download directory updated')),
      );
    }
  }

  Future<void> _reset() async {
    final fs = ref.read(fileSystemServiceProvider);
    await fs.resetDownloadPath();
    await _loadCurrentPath();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Download Directory'),
      content: _isLoading
          ? const SizedBox(
              height: 50,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a directory for your downloads. '
                    'Existing downloads will NOT be moved.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Download Path',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: _pickDirectory,
                        tooltip: 'Browse',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Default'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
