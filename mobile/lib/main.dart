import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models/vault_file.dart';
import 'services/encryption_service.dart';
import 'services/key_store.dart';
import 'services/vault_storage_service.dart';

void main() => runApp(const NevusSafeApp());

class NevusSafeApp extends StatelessWidget {
  const NevusSafeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NevusSafe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const VaultPage(),
      );
}

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  late final VaultStorageService _vault;
  List<VaultFile> _files = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _vault = VaultStorageService(EncryptionService(KeyStore()));
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await _vault.listFiles();
      if (!mounted) return;
      setState(() => _files = files);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final selectedPath = result?.files.single.path;
    if (selectedPath == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final imported = await _vault.importFile(selectedPath);
      if (!mounted) return;
      setState(() => _files = [..._files, imported]);
      _showMessage('${imported.name} berhasil diamankan.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteFile(VaultFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus file?'),
        content: Text('Hapus salinan terenkripsi "${file.name}" dari vault?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _vault.deleteFile(file);
      if (!mounted) return;
      setState(() => _files.removeWhere((candidate) => candidate.id == file.id));
      _showMessage('${file.name} dihapus dari vault.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('NevusSafe'),
          actions: [
            IconButton(
              onPressed: _busy ? null : _loadFiles,
              tooltip: 'Muat ulang',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.lock_outline),
                  ),
                  title: const Text('Vault lokal terenkripsi'),
                  subtitle: Text(
                    _files.isEmpty
                        ? 'File dienkripsi di perangkat sebelum disimpan.'
                        : '${_files.length} file tersimpan aman di perangkat ini.',
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Operasi gagal'),
                    subtitle: Text(_error!),
                    trailing: IconButton(
                      onPressed: () => setState(() => _error = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _files.isEmpty
                  ? _EmptyVault(onImport: _busy ? null : _importFile)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: _files.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(_iconFor(file.mimeType)),
                            title: Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_formatBytes(file.sizeBytes)} • '
                              '${_formatDate(file.updatedAt)}',
                            ),
                            trailing: IconButton(
                              onPressed: _busy ? null : () => _deleteFile(file),
                              tooltip: 'Hapus',
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : _importFile,
          icon: const Icon(Icons.add),
          label: const Text('Amankan file'),
        ),
      );

  IconData _iconFor(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('video/')) return Icons.movie_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({required this.onImport});

  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_off_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Vault masih kosong',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih file untuk mengenkripsinya dengan AES-256-GCM '
                'dan menyimpannya secara lokal.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add),
                label: const Text('Amankan file pertama'),
              ),
            ],
          ),
        ),
      );
}
