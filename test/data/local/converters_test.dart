import 'package:flutter_test/flutter_test.dart';
import 'package:formcoach/data/local/converters.dart';
import 'package:formcoach/domain/enums.dart';

void main() {
  group('MuscleGroupListConverter', () {
    const converter = MuscleGroupListConverter();

    test('round-trips a list', () {
      const muscles = [MuscleGroup.chest, MuscleGroup.fullBody];

      expect(converter.fromSql(converter.toSql(muscles)), muscles);
    });

    test('stores enum names as JSON', () {
      expect(converter.toSql([MuscleGroup.core]), '["core"]');
    });

    test('round-trips an empty list', () {
      expect(converter.fromSql(converter.toSql([])), isEmpty);
    });

    test('rejects an unknown muscle name', () {
      expect(() => converter.fromSql('["wings"]'), throwsArgumentError);
    });
  });

  group('IntListConverter', () {
    const converter = IntListConverter();

    test('round-trips a list', () {
      expect(converter.fromSql(converter.toSql([1, 3, 5])), [1, 3, 5]);
    });

    test('round-trips an empty list', () {
      expect(converter.fromSql('[]'), isEmpty);
    });
  });
}
