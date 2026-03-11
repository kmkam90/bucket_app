import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../core/result.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportData(BuildContext context) async {
    final state = context.read<AppState>();
    final result = await state.export();
    switch (result) {
      case Ok(:final data):
        try {
          final bytes = Uint8List.fromList(utf8.encode(data));
          final fileName = 'bucket_backup_${DateTime.now().toIso8601String().substring(0, 10)}.json';
          await FilePicker.platform.saveFile(
            dialogTitle: '백업 파일 저장',
            fileName: fileName,
            bytes: bytes,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('백업이 완료되었습니다')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('파일 저장 실패: $e')),
            );
          }
        }
      case Err(:final message):
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      final jsonStr = utf8.decode(bytes);

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('데이터 복원'),
          content: const Text('기존 데이터가 모두 교체됩니다. 계속하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('복원', style: TextStyle(color: Color(0xFF6BCB8B))),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final importResult = await state.import(jsonStr);
      switch (importResult) {
        case Ok():
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('데이터가 복원되었습니다')),
            );
          }
        case Err(:final message):
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D3142).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      '데이터 관리',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B8CDE).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.upload_rounded, color: Color(0xFF7B8CDE), size: 20),
                    ),
                    title: const Text('데이터 백업', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    subtitle: const Text('JSON 파일로 내보내기', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
                    onTap: () => _exportData(context),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6BCB8B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.download_rounded, color: Color(0xFF6BCB8B), size: 20),
                    ),
                    title: const Text('데이터 복원', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    subtitle: const Text('JSON 파일에서 가져오기', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
                    onTap: () => _importData(context),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
