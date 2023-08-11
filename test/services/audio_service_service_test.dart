import 'package:flutter_test/flutter_test.dart';
import 'package:jamtalkie/app/app.locator.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('AudioServiceServiceTest -', () {
    setUp(() => registerServices());
    tearDown(() => locator.reset());
  });
}
