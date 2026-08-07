
# Spendly

[![Flutter Version](https://img.shields.io/badge/Flutter-%3E%3D3.3.0-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Supported-orange.svg)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-lightgrey.svg)](#)

Spendly is a premium, high-performance fintech application built with Flutter, designed to revolutionize how individuals and groups manage their finances. By combining personal expense tracking with powerful group settlement features, Spendly provides a seamless, real-time ecosystem for financial transparency.

## 🚀 Overview

Managing shared expenses—from roommates splitting utilities to friends on a vacation—often leads to complexity and friction. Spendly solves this by providing a centralized, real-time platform where users can log expenses, categorize spending, and settle debts with a single tap. 

Built with a **Feature-First Architecture**, Spendly ensures scalability and maintainability, leveraging the power of Firebase for backend services and Riverpod for robust state management.

### Key Value Propositions
*   **Real-Time Synchronization**: Instant updates across all devices using Cloud Firestore.
*   **Group Dynamics**: Create groups, invite friends, and split bills using various logic.
*   **Data-Driven Insights**: Beautifully rendered charts to visualize spending habits.
*   **Premium UI/UX**: Smooth animations and a modern design language powered by `flutter_animate` and `google_fonts`.

---

## ✨ Features

### 🔐 Authentication & Security
*   **Firebase Auth**: Secure login via email/password.
*   **Social Integration**: One-tap Google Sign-In support.
*   **Session Management**: Persistent login states using `shared_preferences`.

### 📊 Personal Finance & Analytics
*   **Expense Tracking**: Log individual expenses with categories, timestamps, and attached receipt previews.
*   **Visual Analytics**: Interactive pie and bar charts via `fl_chart` to monitor monthly burn rates.
*   **Activity Feed**: A chronological history of all financial transactions and updates.

### 👥 Group Management & Settlements
*   **Shared Ledgers**: Create groups for specific events or households.
*   **Smart Settlements**: Algorithm-driven debt simplification with robust provider synchronization to ensure accurate "settle up" flows.
*   **Comments & Interaction**: Discuss specific expenses within the app to clarify costs.

### 🛠 Core Utilities
*   **Receipt Uploads & Interactive Viewer**: Upload receipts seamlessly using `image_picker` integrated with `Cloudinary` cloud storage, featuring an interactive image viewer to inspect uploaded receipts and documents in detail.
*   **Theming**: Dynamic theme support (Light/Dark mode) defined in the core configuration.
*   **Deep Linking**: Advanced routing handled by `go_router`.
*   **Flexible Environments**: Support for toggling between **Demo Mode** and **Original Mode** via app configuration.

---
## 🛠 Tech Stack

| Category | Technology |
| :--- | :--- |
| **Framework** | [Flutter (Dart)](https://flutter.dev) |
| **State Management** | [Riverpod](https://riverpod.dev) |
| **Backend/DB** | [Firebase (Firestore, Security Rules, Auth)](https://firebase.google.com) |
| **Navigation** | [GoRouter](https://pub.dev/packages/go_router) |
| **Charts** | [FL Chart](https://pub.dev/packages/fl_chart) |
| **Animations** | [Flutter Animate](https://pub.dev/packages/flutter_animate) |
| **Local Storage** | [Shared Preferences](https://pub.dev/packages/shared_preferences) |

---
## 🏗 Architecture

Spendly follows a **Feature-First / Layered Architecture**, separating concerns to ensure the codebase remains clean as it grows.

```text
lib/
├── core/                # Global configurations, shared widgets, and services
│   ├── config/          # App constants and environment setup
│   ├── models/          # Shared data models
│   ├── repositories/    # Abstract data access layers
│   ├── router/          # GoRouter definitions
│   ├── theme/           # UI styling and colors
│   └── widgets/         # Reusable UI components (Buttons, Inputs)
├── features/            # Independent modules by business logic
│   ├── auth/            # Login, Signup, Password recovery
│   ├── dashboard/       # Main overview screen
│   ├── expenses/        # Expense creation and listing
│   ├── groups/          # Group management logic
│   └── analytics/       # Data visualization logic
└── main.dart            # Application entry point
```

---

## 🚦 Getting Started

### Prerequisites
*   Flutter SDK: `>=3.3.0`
*   Dart SDK: `>=3.3.0 <4.0.0`
*   A Firebase Project (for backend services)

### Installation

1.  **Clone the repository**
    bash
    git clone https://github.com/Elarionitis/Spendly.git
    cd spendly
    

2.  **Install dependencies**
    bash
    flutter pub get
    

3.  **Firebase Setup**
    *   Create a project in the [Firebase Console](https://console.firebase.google.com/).
    *   Add Android/iOS apps to your Firebase project.
    *   Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
    *   Place them in `android/app/` and `ios/Runner/` respectively.
    *   Alternatively, use the FlutterFire CLI to initialize the configuration:
        bash
        flutterfire configure
        

4.  **Run the application**
    bash
    flutter run
    
## 📖 Usage

### State Management Example (Riverpod)
Spendly uses Riverpod for reactive state. Here is how the expense and settlement states are typically accessed and synchronized:

dart
// Accessing the expense provider
final expenseList = ref.watch(expenseProvider);

// Monitoring settlement synchronization
final settlementState = ref.watch(settlementProvider);

expenseList.when(
  data: (expenses) => ListView.builder(
    itemCount: expenses.length,
    itemBuilder: (context, index) => ExpenseTile(expenses[index]),
  ),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);


### Cloudinary Integration
Receipts and profile images are uploaded to Cloudinary. Here is an example of uploading an image file:

dart
final cloudinaryService = ref.read(cloudinaryServiceProvider);
final imageUrl = await cloudinaryService.uploadImage(imageFile);


### Interactive Image Viewer
Uploaded receipts and transaction attachments can be opened in an interactive image viewer widget for close inspection:

dart
// Open the uploaded image in the interactive viewer
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ImageViewer(imageUrl: imageUrl),
  ),
);


### Navigation
Routing is centralized in `lib/core/router/`:

dart
context.pushNamed(AppRoute.expenseDetails.name, pathParameters: {'id': '123'});


### Configuration Modes
The application environment can be toggled in `lib/core/config/app_config.dart`. This allows developers to switch between a demo environment and the original production-ready mode.

---
## 🧪 Development

### Running Tests
Ensure code quality by running the test suite. Tests are maintained to align with the latest UI and logic changes:
bash
flutter test


### Code Style
This project adheres to `flutter_lints`. To check for linting issues:
bash
flutter analyze


### Firebase Configuration
Firestore security rules and database indexes are managed locally in `firestore.rules` and `firestore.indexes.json`. These can be deployed to Firebase using the CLI:
bash
firebase deploy --only firestore


### Build Configuration
When updating platform-specific settings, ensure that the build scripts (e.g., `android/app/build.gradle.kts`) are correctly configured for the target environment and dependencies.
## 🚀 Deployment

### Android
1. Update the version in `pubspec.yaml`.
2. Run the build command:
   ```bash
   flutter build apk --release
   ```

### iOS
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Ensure a valid Provisioning Profile is set.
3. Run:
   ```bash
   flutter build ios --release
   ```

---

## 🗺 Roadmap
- [ ] **OCR Receipt Scanning**: Automatically extract data from receipts using ML Kit.
- [ ] **Multi-Currency Support**: Real-time currency conversion for international trips.
- [ ] **Export Reports**: Generate PDF/CSV monthly financial statements.
- [ ] **Budgeting Mode**: Set monthly limits for specific categories.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing
Contributions are what make the open-source community such an amazing place to learn, inspire, and create.
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📞 Contact
**Project Maintainer**: [Elarionitis](https://github.com/Elarionitis)  
**Project Link**: [https://github.com/Elarionitis/Spendly](https://github.com/Elarionitis/Spendly)
