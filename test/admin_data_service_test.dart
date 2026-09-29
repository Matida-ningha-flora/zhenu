import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhendu_app/data/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('collecte les traductions et classe les recherches', () async {
    await AdminDataService.recordTranslation('bonjour');
    await AdminDataService.recordTranslation();
    await AdminDataService.recordDictionarySearch('merci');
    await AdminDataService.recordDictionarySearch('merci');

    final analytics = await AdminDataService.loadAnalytics();
    expect(analytics['translations'], 2);
    expect(analytics['dictionarySearches'], 2);
    final topSearch = AdminDataService.topSearches(analytics).first;
    expect(topSearch.key, 'MERCI');
    expect(topSearch.value, 2);
  });

  test('sauvegarde les avatars et les règles administratives', () async {
    final avatars = await AdminDataService.loadAvatars();
    avatars.add({
      'id': 'custom',
      'name': 'Avatar personnalisé',
      'type': '3d',
      'source': 'https://example.test/avatar.png',
      'enabled': true,
    });
    await AdminDataService.saveAvatars(avatars);
    await AdminDataService.saveSettings({
      ...AdminDataService.defaultSettings,
      'sessionTimeoutMinutes': 60,
    });

    expect((await AdminDataService.loadAvatars()).last['id'], 'custom');
    expect(
        (await AdminDataService.loadSettings())['sessionTimeoutMinutes'], 60);
  });
}
