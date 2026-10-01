# Locara ??

Locara (formerly a fork of locara) is a free, open-source, and highly secure app that allows you to share files and messages with nearby devices over your local network without needing an internet connection.

This project has been completely overhauled with a new **Glassmorphism UI**, **True Cyan OLED Dark Mode**, and enhanced security limitations to ensure the best performance and safety.

## ? Features

- **Radical UI Redesign:** Features a sleek floating navigation bar, 20px rounded glassmorphic cards, and dynamic gradient backgrounds.
- **Secure File Transfer:** Uses a secure communication protocol via REST API and HTTPS encryption. TLS/SSL certificates are generated on the fly.
- **No Internet Required:** Works entirely over your local Wi-Fi or LAN.
- **Cross-Platform:** Available for Android, iOS, macOS, Windows, and Linux.

## Screenshots

*(Coming Soon)*

## How It Works

Locara leverages a secure communication protocol allowing devices to communicate via a REST API. All data is transmitted securely over HTTPS, ensuring maximum security on your local network.

## Building (via GitHub Actions)

You do not need to install complex build tools on your machine. Locara is configured to build automatically via GitHub Actions:

1. Push the code to your GitHub repository.
2. Go to the **Actions** tab.
3. Select your desired platform workflow (e.g., Build Android APK, Build Windows exe, Build macOS).
4. Click **Run workflow** to generate the installation files.

## Local Development

To compile Locara from the source code locally:

1. Install Flutter
2. Install Rust
3. Run cd app
4. Run lutter pub get
5. Run lutter run

## Troubleshooting

| Issue              | Solution                                                                                                                                |
|--------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Device not visible | Disable AP-Isolation on your router.                                                                                                    |
| Device not visible | (Windows) Configure your network as "private".                                                                                          |
| Device not visible | (macOS/iOS) Toggle the "Local Network" permission in OS Privacy settings.                                                               |
| Device not visible | Temporarily disable your VPN if it blocks local network traffic.                                                                        |


