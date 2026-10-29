import 'package:flutter/material.dart';
import '../logic/pvc_projects.dart';

Future<bool> confirmPvcProject(
        BuildContext context, String title, String message) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Continue')),
                ])) ??
    false;

class PvcProjectNameDialog extends StatefulWidget {
  const PvcProjectNameDialog({super.key, required this.name});
  final String name;
  @override
  State<PvcProjectNameDialog> createState() => _PvcProjectNameDialogState();
}

class _PvcProjectNameDialogState extends State<PvcProjectNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) Navigator.pop(context, _name.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.all(12),
          title: const Text('Save PVC project'),
          content: Form(
              key: _form,
              child: TextFormField(
                  key: const ValueKey('pvcProjectName'),
                  controller: _name,
                  autofocus: true,
                  maxLength: 80,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Project name'),
                  onFieldSubmitted: (_) => _save(),
                  validator: (value) {
                    try {
                      PvcProjectRepository.validName(value ?? '');
                      return null;
                    } on FormatException catch (e) {
                      return e.message;
                    }
                  })),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(onPressed: _save, child: const Text('Save project')),
          ]);
}

class PvcProjectListDialog extends StatefulWidget {
  const PvcProjectListDialog(
      {super.key, required this.repository, required this.onDelete});
  final PvcProjectRepository repository;
  final void Function(String id) onDelete;
  @override
  State<PvcProjectListDialog> createState() => _PvcProjectListDialogState();
}

class _PvcProjectListDialogState extends State<PvcProjectListDialog> {
  late Future<List<PvcProjectEntry>> _entries = widget.repository.list();
  bool _busy = false;
  String? _error;
  Future<void> _delete(PvcProjectEntry entry) async {
    if (_busy) return;
    if (!await confirmPvcProject(context, 'Delete ${entry.name}?',
        'This removes the saved project from this device. The open calculation will remain.')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.delete(entry.id);
      widget.onDelete(entry.id);
      if (mounted) {
        setState(() {
          _entries = widget.repository.list();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not delete project. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          insetPadding: const EdgeInsets.all(12),
          title: const Text('Saved PVC projects'),
          content: SizedBox(
              width: 480,
              height: (MediaQuery.sizeOf(context).height * .5).clamp(100, 440),
              child: Column(children: [
                if (_error != null) Text(_error!),
                Expanded(
                    child: FutureBuilder<List<PvcProjectEntry>>(
                        future: _entries,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                      'Could not read projects. Your saved data has not been changed.'),
                                  TextButton(
                                      onPressed: () => setState(() {
                                            _entries = widget.repository.list();
                                          }),
                                      child: const Text('Retry')),
                                ]);
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.data!.isEmpty) {
                            return const Center(
                                child: Text('No saved PVC projects yet.'));
                          }
                          return ListView(children: [
                            for (final entry in snapshot.data!)
                              ListTile(
                                title: Text(entry.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: entry.invalid
                                    ? const Text(
                                        'Cannot open. Saved data is invalid.')
                                    : null,
                                onTap: _busy || entry.invalid
                                    ? null
                                    : () => Navigator.pop(context, entry),
                                trailing: IconButton(
                                    tooltip: 'Delete ${entry.name}',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed:
                                        _busy ? null : () => _delete(entry)),
                              )
                          ]);
                        })),
              ])),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Close'))
          ]);
}
