import 'package:flutter_test/flutter_test.dart';
import 'package:studycompete/features/stats/models/shadow_soldier.dart';

void main() {
  group('ShadowSoldier Catalog & Scaling', () {
    test('contains all 5 canonical Solo-Leveling shadows', () {
      final shadows = ShadowCatalog.allShadows;
      expect(shadows.length, equals(5));

      final names = shadows.map((s) => s.name).toList();
      expect(names, containsAll(['Igris', 'Tank', 'Iron', 'Beru', 'Bellion']));
    });

    test('unlock levels scale progressively up to Level 50', () {
      final shadows = ShadowCatalog.allShadows;
      expect(shadows.first.unlockLevel, equals(10));
      expect(shadows.last.unlockLevel, equals(50));
      expect(shadows.last.name, equals('Bellion'));
      expect(shadows.last.buffStat, equals('ALL'));
      expect(shadows.last.buffMultiplier, equals(0.25));
    });

    test('Igris boosts INT and has bloodred color', () {
      final igris = ShadowCatalog.allShadows.firstWhere((s) => s.id == 'igris');
      expect(igris.buffStat, equals('INT'));
      expect(igris.buffMultiplier, equals(0.10));
      expect(igris.title, equals('The Bloodred Commander'));
    });
  });
}
