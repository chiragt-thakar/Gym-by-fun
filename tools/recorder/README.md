# Landmark recorder tools

Record on a phone with **Settings → Developer → Landmark recorder** (33 body
points per frame, never video), pull the files, and replay them:

```bash
adb pull /data/data/app.motionquest/app_flutter/recordings ./recordings   # debug builds
dart run bin/replay.dart ./recordings            # accuracy report, exit 1 if the gate fails
dart run bin/replay.dart ./recordings --json     # machine-readable
dart run bin/replay.dart --make-synthetic /tmp/s # sample files to try the tool
```

Copy consented recordings into `packages/motion_core/test/recordings/` and
they join the CI accuracy gate automatically.
