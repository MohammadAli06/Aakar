import 'package:craft_connect/core/services/studio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'Suggestions fill gaps without replacing artisan values or business data',
      () {
    final draft = {
      'title': 'My chosen name',
      'material': '',
      'stock': 0,
      'customizable': false
    };
    final merged = mergeCatalogSuggestions(draft, {
      'title': 'Model name',
      'material': 'Bamboo',
      'colour': 'Brown',
      'price': 500,
      'approved': true
    });
    expect(merged, {
      'title': 'My chosen name',
      'material': 'Bamboo',
      'colour': 'Brown',
      'stock': 0,
      'customizable': false
    });
    expect(draft['material'], '');
  });
}
