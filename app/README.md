# BagMandi - India's Bag Industry Marketplace

Flutter + Firebase B2B marketplace app connecting bag buyers with manufacturers.

## Mobile App Features

### Buyer
- Phone OTP login with role selection
- Today's PP Rate with price trends
- Post bag requirements
- Receive & compare manufacturer quotes
- Chat with manufacturers
- Order tracking

### Manufacturer
- Dashboard with business stats
- Browse buyer enquiries & send quotes
- Material marketplace (Raw Material, Dead Stock, Machines, Services)
- Order management
- Company profile with capabilities

## Setup

### Prerequisites
- Flutter SDK 3.2+ ([Install Flutter](https://docs.flutter.dev/get-started/install))
- Firebase project ([Firebase Console](https://console.firebase.google.com))

```bash
cd d:\100Apk\Bagmandi
flutter pub get
flutter run
```

### Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Enable in Firebase Console:
- **Authentication** → Phone sign-in
- **Cloud Firestore** → Create database
- **Firebase Storage** → Enable

## Demo Mode

Without Firebase configured, the app runs with mock data. Use any 6-digit OTP to login.

## Project Structure

```
Bagmandi/
├── lib/                 # Mobile app (Buyer + Manufacturer)
├── android/
├── ios/
└── web/
```

## Tech Stack

- **Flutter** — Cross-platform mobile UI
- **Firebase Auth** — Phone OTP authentication
- **Cloud Firestore** — Real-time database
- **Provider** — State management
- **GoRouter** — Navigation

## Color Theme

- Primary Green: `#28A745`
- Dark: `#343A40`
- Background: `#F8F9FA`
