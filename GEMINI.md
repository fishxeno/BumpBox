# BumpBox: Smart Second-hand Marketplace Lockers

BumpBox is a smart vending locker system that automates the sale of second-hand items. It features automated condition assessment via computer vision, dynamic pricing based on interest and time decay, and a "test-before-you-buy" mechanism.

## Project Architecture

The project is divided into several key components:

### 1. Backend Server (`/server`)
- **Technology:** Node.js, Express, ES Modules.
- **Core Logic:**
  - **Payments:** Integrated with Stripe for both immediate captures and pre-authorization holds.
  - **Hardware Control:** Uses MQTT (HiveMQ) to send unlock commands to ESP32-managed solenoids.
  - **AI Vision:** Integrates with Google Cloud Vision API for object detection and condition assessment.
  - **Dynamic Pricing:** Implements pricing logic based on category, condition, time decay, and interest metrics.
  - **Database:** MySQL for storing item listings, user payouts, and transaction history.
- **Key Files:** `server.js` (entry point), `routes/detectObject.js`, `services/pricingService.js`, `storage.js` (in-memory state for hardware coordination).

### 2. Web Frontends
- **Seller Portal (`/bumpbox`):**
  - **Technology:** React, Vite, TypeScript, Bootstrap, Formik.
  - **Purpose:** Allows sellers to list items, set floor prices, and manage their listings.
- **Polished UI/Kiosk (`/uiux`):**
  - **Technology:** React, Vite, TypeScript, Tailwind CSS, Radix UI.
  - **Purpose:** A more modern, interactive interface intended for the physical kiosk or high-fidelity user experience.

### 3. Mobile Frontend (`/mobile_frontend/bumpbox_panel`)
- **Technology:** Flutter.
- **Purpose:** Acts as the kiosk control panel.
- **Features:**
  - **Attention Detection:** Uses Google ML Kit Face Detection to measure user dwell time and interest.
  - **Kiosk Dashboard:** Interfaces with the backend to trigger captures and display detected item info.

### 4. Hardware Firmware (`/esp32/bumpbox_camera`)
- **Technology:** C++/Arduino via PlatformIO.
- **Hardware:** ESP32-CAM.
- **Purpose:** Captures images for item detection, monitors weight sensors (planned), and controls solenoid locks via MQTT commands.

---

## Building and Running

### Backend
```bash
cd server
npm install
# Ensure .env file is configured with STRIPE_SECRET_KEY, STRIPE_WEBHOOK_KEY, GOOGLE_VISION_API_KEY, etc.
npm start
```

### Webapps (BumpBox or UIUX)
```bash
cd bumpbox # or cd uiux
npm install
npm run dev # or npm start
```

### Mobile App
```bash
cd mobile_frontend/bumpbox_panel
flutter pub get
flutter run
```

### ESP32 Firmware
```bash
cd esp32/bumpbox_camera
pio run --target upload
```

---

## Core Workflows

1.  **Item Ingestion (Seller):**
    - Seller reserves a locker and deposits the item.
    - ESP32 captures an image, sends it to `POST /detect-object`.
    - Backend identifies the item and suggests a price based on `priceMap.json`.
2.  **Dynamic Pricing:**
    - Base price is set upon ingestion.
    - Dwell time (from Flutter ML Kit) or digital interest (clicks) triggers a "Surge" price increase.
    - Time decay gradually reduces price over 7 days.
3.  **Purchase & "Test Before Buy":**
    - Buyer pays/authorizes via Stripe.
    - Backend triggers MQTT `unlock` command.
    - For testing, a 5-minute timer is started (`scheduleCapture`). If the item is returned (monitored by sensors), the hold is released.

## Development Conventions

- **Security:** Never commit `.env` files. Stripe and Google Vision keys are required for full functionality.
- **Mocking:** Set `USE_MOCK_VISION=true` in `.env` to test detection without calling the Google Vision API.
- **Deployment:** Commits including `[deploy]` trigger a GitHub Action to deploy to AWS.
