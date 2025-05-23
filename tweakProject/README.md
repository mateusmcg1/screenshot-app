# iOS Screenshot Monitor

A jailbreak tweak that automatically captures screenshots and uploads them to a server.

## Features

- Takes screenshots at configurable intervals (default: 60 seconds)
- Uploads screenshots to your API endpoint
- Runs in the background
- Includes device ID and timestamp with each upload

## Installation

### For Users (with jailbroken devices)

1. Add this repository to Sileo:
   - Open Sileo
   - Go to Sources
   - Add your repository URL: `https://your-github-username.github.io/your-repo-name`

2. Search for "ScreenshotMonitor" and install it
3. Respring your device

### For Developers

#### Prerequisites

- A Mac or Linux system
- [Theos](https://theos.dev/docs/installation) installed

#### Setup and Compilation

1. Clone this repository
2. Edit `ScreenshotMonitor.x` and change the `API_ENDPOINT` to your server URL
3. Run `make package` to create the .deb file
4. The .deb file will be in the `packages/` directory

## Configuration

Open `ScreenshotMonitor.x` to modify:

- `API_ENDPOINT`: The URL where screenshots will be uploaded
- `SCREENSHOT_INTERVAL`: Time between screenshots in seconds (default: 60 seconds)

## API Endpoint Requirements

Your server should accept:
- HTTP POST requests with `multipart/form-data`
- Form fields:
  - `timestamp`: Unix timestamp when the screenshot was taken
  - `screenshot`: The JPEG image file
- The device ID is included in the URL path: `{API_ENDPOINT}{DEVICE_ID}`

## Repository Structure

```
your-repo/
├── debs/           # Contains the .deb file
├── Packages        # Generated package list
├── Packages.bz2    # Compressed package list
└── Release        # Repository metadata
```

## Building the Repository

After creating the repository structure:

1. Place your .deb file in the `debs/` directory
2. Run these commands to generate the repository files:
   ```bash
   dpkg-scanpackages debs /dev/null > Packages
   bzip2 -k Packages
   ```

3. Create a Release file:
   ```bash
   echo "Origin: Your Name
   Label: Your Repository Name
   Suite: stable
   Version: 1.0
   Codename: ios
   Architectures: iphoneos-arm
   Components: main
   Description: Your repository description" > Release
   ```

4. Commit and push all files to GitHub
5. Enable GitHub Pages in your repository settings
6. Your repository URL will be: `https://your-github-username.github.io/your-repo-name`

## Notes on Xcode vs Theos

This tweak is designed for jailbroken devices using Theos, as this approach:
- Doesn't require a paid Apple Developer account
- Provides deeper system access for screenshot functionality
- Allows for easier distribution across multiple jailbroken devices via Cydia

A regular iOS app built with Xcode would have limitations accessing system-level screenshot capabilities. 