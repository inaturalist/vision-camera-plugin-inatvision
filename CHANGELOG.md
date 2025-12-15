# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Types of changes
### Added
for new features.
### Changed
for changes in existing functionality.
### Deprecated
for soon-to-be removed features.
### Removed
for now removed features.
### Fixed
for any bug fixes.
### Security
in case of vulnerabilities.

## [Unreleased] - YYYY-MM-DD
### Changed
- Breaking: Changed to use LiteRT instead of tensorflow-lite on Android. Set version with `litertVersion` property instead of `tensorflowVersion`.
- Updated peer dependencies to latest versions.
## [5.3.0] - 2025-08-29
### Changed
- Updated react-native-vision-camera dependency to >= v4.1.0 this includes native handling of camera orientation
### Removed
- patchedOrientationAndroid property
- Custom INatVisionError class
## [5.2.0] - 2025-03-09
### Removed
- Two properties (`iconic_class_id` and `spatial_class_id`) from `Prediction` and taxonomy file
## [5.1.0] - 2025-03-09
### Added
- Support for cv model 2.20
## [5.0.0] - 2025-02-28
### Added
- Common ancestor calculation for predictions from image file
- iOS now also returns ancestor_ids for predictions
### Changed
- Breaking: Prediction scores are now in range of 0-100
- Prediction from image file now uses top score * 0.001 as threshold for filtering before aggregating scores up the taxonomic tree


