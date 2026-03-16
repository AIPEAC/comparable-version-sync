# Changelog

## 1.0.0

### default-agent
- Initial project setup: package skeleton, folder structure, enums, models, widget stubs.
- Cloned `google/dart-json_diff` (Apache 2.0) into `lib/third_party/dart_json_diff/`.
- Added dependencies: `sqflite`, `sqflite_common_ffi`, `sqflite_common_ffi_web`, `path`, local `json_diff`.
- Wrote full architecture in `ARCHITECTURE.md` and `architecture.mdc`.
- Defined public API via `ComparableVersionWidget.rawView` and `.diffView` named constructors.
