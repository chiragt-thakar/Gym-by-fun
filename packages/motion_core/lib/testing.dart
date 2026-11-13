/// TEST AND DEVELOPMENT SUPPORT ONLY — synthetic landmark generators for
/// replay tests, the accuracy tool and the app's developer-only simulated
/// input (`--dart-define=JOYNETIC_INPUT=sim`). Never reachable in a release
/// build: real on-device pose estimation is the only input players get.
library;

export 'src/testing/synthetic.dart';
export 'src/testing/stick.dart';
