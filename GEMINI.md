# Project Overview

This project is a Flutter package named `cosmos_epub` that provides a customizable EPUB reader widget. It allows developers to easily integrate EPUB reading functionality into their Flutter applications.

## Main Technologies

*   **Flutter**: The UI toolkit used for building the application.
*   **Dart**: The programming language used for the project.
*   **Isar**: A fast, embedded, and cross-platform database used for storing book progress.
*   **epubx**: A Dart library for parsing EPUB files.
*   **GetX**: A state management library used for reactive programming.
*   **GetStorage**: A lightweight and fast key-value storage.

## Architecture

The package is structured as follows:

*   `lib/cosmos_epub.dart`: The main entry point of the package, providing static methods to open EPUB files from different sources (assets, local storage, URL).
*   `lib/show_epub.dart`: The main UI widget for the EPUB reader. It handles rendering the EPUB content, theming, font size changes, brightness control, and chapter navigation.
*   `lib/Helpers/pagination.dart`: Contains the logic for paginating the EPUB content.
*   `lib/Component/`: Contains UI components like buttons and constants.
*   `lib/Model/`: Contains data models for book progress and chapters.
*   `lib/widgets/`: Contains various widgets used in the reader UI, such as brightness slider, font settings, and theme selection.

# Building and Running

To use this package in a Flutter project, add it as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  cosmos_epub: <latest_version>
```

Then, run `flutter pub get` to install the package.

The example directory contains a sample application that demonstrates how to use the package. To run the example:

```bash
cd example
flutter run
```

# Development Conventions

*   **State Management**: The project uses GetX for state management, particularly for reactive variables and dependency injection.
*   **Storage**: GetStorage is used for caching theme and font settings, while Isar is used for persisting book progress.
*   **UI**: The UI is built with Flutter widgets and organized into several files under the `lib/widgets` and `lib/Component` directories.
*   **Testing**: The project has a `test` directory, but it is currently empty.
*   **Linting**: The project uses `flutter_lints` for code analysis.
*   **Internationalization**: The package has some support for localization, with a `translations` directory and the ability to update the locale.
