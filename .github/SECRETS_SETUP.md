# GitHub Actions Secrets Setup Guide

This guide helps you configure all required GitHub Secrets for the iBurn iOS CI/CD workflows.

## Overview

GitHub Actions workflows require various secrets for:
- **Building:** API keys and configuration values
- **Testing:** Mock values for CI validation  
- **Deploying:** Code signing certificates and App Store Connect credentials

## Required Secrets

### Basic CI Secrets (Required for all workflows)

Navigate to **Repository Settings → Secrets and variables → Actions** and add:

#### API Keys & Configuration
```
MAPBOX_ACCESS_TOKEN
├─ Description: MapBox API access token for map services
├─ Source: MapBox developer console
└─ Example: pk.eyJ1IjoiZXhhbXBsZSIsImEiOiJjazE...

CRASHLYTICS_API_TOKEN  
├─ Description: Firebase Crashlytics API token for crash reporting
├─ Source: Firebase console → Project settings → Service accounts
└─ Example: 1:123456789:android:abcdef...

HOCKEY_BETA_IDENTIFIER
├─ Description: TestFlight beta app identifier (if used)
├─ Source: Legacy HockeyApp (may be empty for new projects)
└─ Example: abcd1234567890ef...

HOCKEY_LIVE_IDENTIFIER
├─ Description: Production app identifier (if used)  
├─ Source: Legacy HockeyApp (may be empty for new projects)
└─ Example: ef0987654321dcba...

EMBARGO_PASSCODE_SHA256
├─ Description: SHA256 hash of embargo passcode for restricted data
├─ Source: Generate using: echo -n "your_passcode" | shasum -a 256
└─ Example: e3b0c44298fc1c149afbf4c8996fb9242...

UPDATES_URL
├─ Description: URL for app update checks
├─ Source: Your update service endpoint
└─ Example: https://api.example.com/updates

MAPBOX_STYLE_URL
├─ Description: MapBox custom style URL
├─ Source: MapBox Studio style configuration
└─ Example: mapbox://styles/username/ckl9m8t0q...
```

### Deployment Secrets (Required for deploy.yml workflow)

#### Google Services
```
GOOGLE_SERVICE_INFO_PLIST
├─ Description: Base64-encoded GoogleService-Info.plist file
├─ Source: Firebase console → Project settings → iOS app
└─ Setup: base64 -i GoogleService-Info.plist | pbcopy
```

#### App Store Connect API
```
APP_STORE_CONNECT_API_KEY
├─ Description: Base64-encoded App Store Connect API private key (.p8 file)
├─ Source: App Store Connect → Users and Access → Keys
└─ Setup: base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy

APP_STORE_CONNECT_API_KEY_ID
├─ Description: App Store Connect API key ID
├─ Source: App Store Connect → Users and Access → Keys (Key ID column)
└─ Example: XXXXXXXXXX

APP_STORE_CONNECT_API_ISSUER_ID
├─ Description: App Store Connect API issuer ID
├─ Source: App Store Connect → Users and Access → Keys (Issuer ID)
└─ Example: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

#### Code Signing
```
BUILD_CERTIFICATE_BASE64
├─ Description: Base64-encoded iOS distribution certificate (.p12 file)
├─ Source: Apple Developer Portal → Certificates
└─ Setup: base64 -i ios_distribution.p12 | pbcopy

P12_PASSWORD
├─ Description: Password for the .p12 certificate file
├─ Source: Password you set when exporting the certificate
└─ Example: your_certificate_password

BUILD_PROVISION_PROFILE_BASE64
├─ Description: Base64-encoded provisioning profile (.mobileprovision)
├─ Source: Apple Developer Portal → Profiles
└─ Setup: base64 -i YourApp_AppStore.mobileprovision | pbcopy

KEYCHAIN_PASSWORD
├─ Description: Random password for temporary build keychain
├─ Source: Generate a random password (will be used only during CI)
└─ Example: randomly_generated_secure_password_123
```

#### Fastlane Authentication
```
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
├─ Description: App-specific password for Apple ID
├─ Source: Apple ID → Sign-In and Security → App-Specific Passwords
└─ Example: abcd-efgh-ijkl-mnop

FASTLANE_SESSION
├─ Description: Fastlane session token (for 2FA bypass)
├─ Source: Run `fastlane spaceauth -u your_apple_id` locally
└─ Example: ---\nMIIEcgIBADANBgkqhkiG9w0BAQEFA...

MATCH_PASSWORD
├─ Description: Fastlane Match password (if using match for code signing)
├─ Source: Your team's match repository password
└─ Example: your_match_repository_password
```

## Setup Instructions

### Step 1: Repository Configuration
1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each required secret

### Step 2: Certificate Setup
For iOS certificates and provisioning profiles:

```bash
# Export certificate from Keychain Access as .p12 file
# Then encode to base64:
base64 -i your_certificate.p12 | pbcopy

# Encode provisioning profile:
base64 -i YourApp_AppStore.mobileprovision | pbcopy
```

### Step 3: App Store Connect API Setup
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **Users and Access** → **Keys**
3. Create a new API key with **Developer** access
4. Download the `.p8` file and note the Key ID and Issuer ID
5. Encode the `.p8` file: `base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy`

### Step 4: Google Services Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project → **Project Settings** → **General**
3. Download `GoogleService-Info.plist` for your iOS app
4. Encode it: `base64 -i GoogleService-Info.plist | pbcopy`

### Step 5: Fastlane Session Setup
```bash
# Install fastlane if not already installed
gem install fastlane

# Generate session token (handles 2FA)
fastlane spaceauth -u your_apple_id@example.com

# Copy the entire output to FASTLANE_SESSION secret
```

## Verification

### Test CI Workflow
1. Push a commit to a feature branch
2. Create a pull request to `develop`
3. Verify the PR workflow runs successfully
4. Check that build and test steps complete without errors

### Test Deployment Workflow
1. Go to **Actions** → **Deploy**
2. Click **Run workflow**
3. Select `refresh_dsyms` as a safe test
4. Verify it completes successfully

### Common Issues

#### Missing Secrets
**Error:** `The secret 'SECRET_NAME' is not defined`
**Solution:** Add the missing secret to repository settings

#### Invalid Base64 Encoding
**Error:** `Invalid base64 input`
**Solution:** Re-encode the file using `base64 -i filename | pbcopy`

#### Certificate/Profile Issues
**Error:** `Code signing identity not found`
**Solution:** Verify certificate and provisioning profile are valid and properly encoded

#### Fastlane Authentication Issues
**Error:** `Two-step verification required`
**Solution:** Update `FASTLANE_SESSION` using `fastlane spaceauth`

## Security Best Practices

1. **Rotate Secrets Regularly:** Update certificates and API keys before expiration
2. **Use App-Specific Passwords:** Never use your main Apple ID password
3. **Limit Access:** Only give secrets access to necessary team members
4. **Monitor Usage:** Review workflow logs for any authentication issues
5. **Test Thoroughly:** Validate all workflows before production deployment

## Support

If you encounter issues:
1. Check workflow logs in GitHub Actions for specific error messages
2. Verify all secrets are correctly set in repository settings
3. Test certificate/provisioning profile validity locally
4. Consult `Docs/2025-07-23-github-actions-migration.md` for migration details

---

**Last Updated:** July 23, 2025  
**Next Review:** October 23, 2025 (certificate expiration check)