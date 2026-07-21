import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class UploadScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const UploadScreen({super.key, this.onBack});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  PlatformFile? _selectedFile;
  String? _selectedTenantId;
  bool _uploading = false;
  bool _uploaded = false;
  List<Map<String, dynamic>> _tenants = [];

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    final api = context.read<ApiService>();
    try {
      final tenants = await api.getTenants();
      if (mounted) {
        setState(() {
          _tenants = tenants.map((t) => {'id': t.id, 'name': t.name}).toList();
          if (_tenants.isNotEmpty) _selectedTenantId = _tenants.first['id'];
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['pdf', 'txt', 'md', 'csv', 'docx', 'html', 'json'],
      type: FileType.custom,
      withData: true,  // Important: loads file bytes into memory
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      // Verify bytes are available
      if (file.bytes == null || file.bytes!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file. Try again.'), backgroundColor: AppTheme.error),
          );
        }
        return;
      }
      setState(() {
        _selectedFile = file;
        _uploaded = false;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null || _selectedTenantId == null) return;

    setState(() => _uploading = true);

    try {
      final api = context.read<ApiService>();
      final bytes = _selectedFile!.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('File data is empty. Please select the file again.');
      }
      final filename = _selectedFile!.name;

      // Show upload progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploading $filename (${_formatSize(bytes.length)})...'),
            backgroundColor: AppTheme.info,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final result = await api.uploadDocument(_selectedTenantId!, bytes, filename);

      if (mounted) {
        setState(() {
          _uploading = false;
          _uploaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${result['filename']} (${result['chunks']} chunks)'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).round()} KB';
    return '${(bytes / 1048576).round()} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final surfaceBg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.border : AppTheme.lightBorder;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: widget.onBack,
                  color: textColor,
                ),
              Icon(Icons.upload_file, color: AppTheme.success, size: 20),
              const SizedBox(width: 8),
              Text('Upload Document', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: textColor,
              )),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tenant selector
                Text('Select Tenant', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: subtextColor,
                )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedTenantId,
                    isExpanded: true,
                    dropdownColor: surfaceBg,
                    underline: const SizedBox(),
                    items: _tenants.map<DropdownMenuItem<String>>((t) => DropdownMenuItem<String>(
                      value: t['id'] as String?,
                      child: Text(t['name'] ?? 'Unknown', style: TextStyle(color: textColor)),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedTenantId = v),
                  ),
                ),

                const SizedBox(height: 24),

                // File picker
                Text('Select File', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: subtextColor,
                )),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedFile != null
                            ? AppTheme.success.withOpacity(0.5)
                            : borderColor,
                        width: _selectedFile != null ? 2 : 1,
                      ),
                    ),
                    child: _selectedFile != null
                        ? Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.description, color: AppTheme.success, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedFile!.name,
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatSize(_selectedFile!.size),
                                      style: TextStyle(color: subtextColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                            ],
                          )
                        : Column(
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 40, color: subtextColor.withOpacity(0.4)),
                              const SizedBox(height: 8),
                              Text('Tap to select a file', style: TextStyle(color: subtextColor, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('PDF, TXT, MD, CSV, DOCX, HTML', style: TextStyle(color: subtextColor.withOpacity(0.5), fontSize: 11)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Upload button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedFile != null && _selectedTenantId != null && !_uploading
                        ? _uploadFile
                        : null,
                    icon: _uploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_uploaded ? Icons.check : Icons.upload, size: 18),
                    label: Text(_uploading ? 'Uploading...' : _uploaded ? 'Uploaded!' : 'Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _uploaded ? AppTheme.success : AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor: borderColor,
                    ),
                  ),
                ),

                if (_uploaded) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedFile = null;
                      _uploaded = false;
                    }),
                    child: Text('Upload another file', style: TextStyle(color: AppTheme.primary)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
