# Nirvana Task Adder

A lightweight Flutter application that allows you to quickly add tasks to your [NirvanaHQ](https://nirvanahq.com/) account with minimal friction.

![Nirvana Task Adder](assets/images/logo.ico)

## Features

- **Quick Task Entry**: Add tasks to your NirvanaHQ inbox with just a title and optional notes
- **Global Hotkey**: Access the app from anywhere using Win+Shift+A (Windows only)
- **System Tray Integration**: Runs in the background for easy access (Windows only)
- **Minimal Interface**: Clean, distraction-free design

## Installation

### Windows

1. Download the latest release from the [Releases](https://github.com/yourusername/nirvanahq_task_adder_flutter/releases) page
2. Extract the ZIP file to your desired location
3. Run `nirvanahq_task_adder.exe`

### Building from Source

1. Ensure you have Flutter installed and set up correctly
2. Clone this repository
   ```
   git clone https://github.com/yourusername/nirvanahq_task_adder_flutter.git
   cd nirvanahq_task_adder_flutter
   ```
3. Get dependencies
   ```
   flutter pub get
   ```
4. Build the application
   ```
   # For Windows
   flutter build windows
   
   # For other platforms
   flutter build <platform>
   ```

## Usage

1. Launch the application
2. Log in with your NirvanaHQ credentials
3. Enter a task title (required) and notes (optional)
4. Click "Add Task" or press Ctrl+Enter to submit

### Windows Shortcuts

- **Win+Shift+A**: Show/hide the application window
- **Ctrl+Enter**: Add the current task and minimize the window
- The application continues running in the system tray when closed

## Privacy & Security

- Your NirvanaHQ credentials are stored securely using Flutter Secure Storage
- The application only communicates with the official NirvanaHQ API
- No data is sent to any third-party services

## Dependencies

- flutter_secure_storage: For secure credential storage
- http: For API communication
- crypto: For password hashing
- uuid: For task ID generation
- window_manager, tray_manager, hotkey_manager: For Windows-specific features

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- This is an unofficial client for NirvanaHQ and is not affiliated with or endorsed by Nirvanahq.com
- Built with Flutter and Dart
