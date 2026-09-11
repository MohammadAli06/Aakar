import 'dart:convert';
import 'dart:io';
import '../lib/features/commerce/domain/commerce_engine.dart';

void main() {
  final file = File('backend/app/services/workflow_seed.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(CommerceEngine.seed()));
  stdout.writeln('Exported deterministic shared demo seed.');
}
