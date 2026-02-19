# Project Requirements Document (PRD): Bumpbox

| **Project Name** | Bumpbox |
| :--- | :--- |
| **Version** | **1.1** |
| **Status** | Draft |
| **Context** | Smart Second-hand Marketplace Lockers (MRT/Business Park focus) |

---

## 1. Executive Summary
Bumpbox is a smart vending locker system designed to automate the sale of second-hand items with high convenience for sellers and dynamic pricing mechanisms for buyers. Located in high-traffic areas (e.g., MRT stations, Changi Business Park), it allows busy professionals to "drop and forget" items. The system utilizes AI, computer vision, and IoT sensors to manage pricing, validate item condition, and facilitate a secure "test-before-you-buy" experience.

## 2. User Personas

### 2.1 The Seller (Primary Focus: "The Busy Professional")
*   **Goal:** Wants to get rid of unused items and make money without the hassle of messaging, scheduling meetups, or negotiating.
*   **Pain Point:** Traditional selling platforms require too much active management.
*   **Behavior:** Wants to drop the item in a locker and receive funds via PayNow automatically.

### 2.2 The Buyer ("The Commuter/Deal Hunter")
*   **Goal:** Finds discounted second-hand goods while commuting.
*   **Pain Point:** Fear of buying defective goods; wants to verify condition before purchase.
*   **Behavior:** Browses app or physical locker, impulsive buying if the price is right, values trust (testing mechanism).

---

## 3. Functional Requirements

### 3.1 Dynamic Pricing Engine
The system must autonomously adjust pricing to maximize conversion while respecting seller limits. The pricing logic is driven by automated condition assessment, time decay, and real-time interest (Physical & Digital).

*   **Automated Condition-Based Pricing (Initial Layer):** 
    *   Upon item deposit, the system uses **computer vision (object detection and condition assessment)** and **weight sensors** to automatically evaluate the item.
    *   **Factors Analyzed:**
        1.  **Object Recognition:** AI identifies the product category, brand, and model to establish market baseline.
        2.  **Condition Assessment:** Camera detects scratches, wear, discoloration, and overall cosmetic condition.
        3.  **Weight/Density Verification:** Sensors confirm item authenticity and completeness (e.g., checking if accessories are included).
    *   **Initial Price Calculation:** The system generates a recommended starting price based on condition grade (Excellent/Good/Fair/Poor), which is balanced against the seller's floor price.
    *   Items in better condition automatically receive higher initial pricing within the acceptable range.
*   **Time-Decay Pricing (Base Layer):** The price decreases gradually over the listing period (up to 7 days) to ensure inventory turnover.
*   **Interest-Based Surge Pricing (FOMO Layer):**
    *   **Triggers:**
        1.  **Physical Presence:** Sensors (Heat/Eye tracking) detect a person standing in front of the locker for a specific duration (Dwell Time).
        2.  **Online Interest:** The system tracks real-time App/Web clicks, unique page views, and "Wishlist" adds for the specific item.
    *   **Mechanism:**
        *   When high physical dwell time or a spike in online clicks is detected, the **displayed price increases immediately**.
        *   This entices the potential buyer to purchase immediately before the price rises further.
    *   **Cooldown:** A short period after the physical person leaves or online traffic subsides, the price reverts to the lower "Time-Decay" price.
*   **Seller Inputs:** Seller sets the "Minimum Acceptable Price" (Floor Price). They do not set the active listing price.

### 3.2 Inventory & Listing Management
*   **Listing Duration:** Items are listed for a maximum of 7 days.
*   **Unsold Item Workflow:** If an item is unsold after 7 days, the seller selects an option during the initial listing:
    1.  **Extend:** Pay a fee to keep listed.
    2.  **Auction:** 24-hour auction with no reserve price.
    3.  **Thrift/Export:** Sell to Bumpbox partners for a nominal fee (liquidation).
    4.  **Donate:** Send to charity.
    5.  **Return:** Seller retrieves item.

### 3.3 "Test Before Buy" System
*   **Pre-Authorization:** Buyer requests to "Test." A credit card hold (Stripe) is placed for the full amount.
*   **Unlock & Timer:** Locker opens. Buyer has **5 minutes** to test the item.
*   **Buyer Monitoring:** Cameras/Sensors track the buyer within the immediate vicinity (compound) to ensure they do not swap parts.
*   **Return Validation:**
    *   If returned within 5 mins: System scans item (Weight + Vision). If matches original condition -> Card hold released.
    *   If damaged/swapped: System detects anomaly -> Card charged full amount + penalty.
    *   If kept > 5 mins: Transaction finalized automatically.

### 3.4 Payment System
*   **Buyer:** Stripe integration (Credit/Debit/Apple Pay). Supports immediate capture or pre-auth holds.
*   **Seller:** PayNow integration (Singapore).
    *   System manually triggers payout to seller (waiting period to ensure no disputes, though "immediate" webhook detection is used to verify buyer funds).

### 3.5 Security & Validation (The "Digital Twin")
*   **Ingestion (Seller Drop-off):**
    *   **Video Logging:** Machine records the seller placing the item.
    *   **Volumetric Scan:** Weight sensors create a baseline density profile.
    *   **Visual Scan:** AI Computer Vision scans for scratches and surface details.
*   **Return Verification:**
    *   Upon return, the system compares the current weight, volume, and visual surface against the baseline.
    *   **Anti-Fraud:** Prevents "Sandbag for Laptop" swaps via density checks.

---

## 4. Hardware Requirements

### 4.1 Chassis & Structure
*   **Body:** 3D printed components reinforced with standard vending structural frames.
*   **Doors:**
    *   Transparent acrylic sheets (for physical browsing).
    *   **Mechanism:** Solenoid lock (electronic control) + Spring-loaded (pushes door open upon unlock).
    *   **Sensors:** Magnetic/Switch sensor to detect if the door is fully closed.

### 4.2 Sensors & Electronics
*   **Internal Camera:** High-res camera for product scanning (scratches/condition).
*   **External Sensors:**
    *   Video Camera (Seller recording/Buyer monitoring).
    *   **Interest Sensors:** Eye tracking, Heat/PIR sensors, or Face detection (to measure "Dwell Time" for pricing algo).
*   **Scale/Volume:**
    *   High-precision load cell (Weight).

### 4.3 Interface & Feedback
*   **Main Display:** LCD Screen or Tablet interface for browsing/payment.
*   **Smart Internal Lighting (LED Strips):**
    *   **Green:** Recently Price-Dropped.
    *   **Pulsing:** Auction/Ending Soon.
    *   **Blue:** Testing in Progress (Occupied).
    *   **White:** Standard Display.

---

## 5. Software System Architecture

### 5.1 Mobile App (Seller & Buyer)
*   **Seller:**
    *   Reserve locker slot.
    *   Input item details, floor price, listing days.
    *   Input PayNow number.
*   **Buyer:**
    *   Browse inventory by location.
    *   **Activity Tracking:** App reports clicks and view duration to the server to influence the price.
    *   Unlock locker via App (Bluetooth/Network).

### 5.2 Kiosk UI
*   Simple flow for non-app users to purchase immediately using a card terminal or QR code.

### 5.3 Backend Server
*   **Inventory Database:** Tracks item status, digital twin data (weight/image hash).
*   **Pricing Algorithm:** Real-time calculation engine aggregating:
    1.  Time remaining (Decay).
    2.  Physical Sensor feeds (Surge).
    3.  Online Analytics feeds (Surge).
*   **AI Engine:** Processes images for scratch detection and volume verification.
*   **Payment Gateway:** Stripe Webhook listener for unlocking doors.

---

## 6. User Flows

### 6.1 Seller Flow (Drop-off)
1.  **Reservation:** Seller inputs item info and floor price on App; reserves a locker.
2.  **Arrival:** Seller arrives at machine, scans QR code to identify session.
3.  **Verification:** Machine initiates recording.
4.  **Deposit:** Door opens. Seller places item inside.
5.  **Scanning:** Machine locks door. Internal sensors perform Weight scan. Camera takes high-res photos.
6.  **Confirmation:** "Digital Twin" created. Item goes live.

### 6.2 Buyer Flow (Direct Purchase)
1.  **Browse (Physical or Digital):**
    *   *Physical:* Buyer stands in front of locker. Sensor detects 15s presence. Price increases by 5%.
    *   *Digital:* 10 users click the item on the app simultaneously. Price increases by 5%.
2.  **Pay:** Buyer decides to buy before price increases further.
3.  **Process:** Stripe processes payment -> Webhook triggers Server -> Server triggers Solenoid.
4.  **Collection:** Door pops open. Buyer retrieves item. Door closed. Transaction Complete.

### 6.3 Buyer Flow (Test & Return)
1.  **Request:** Buyer selects "Test Item."
2.  **Auth:** Stripe places hold on funds.
3.  **Unlock:** Door opens. LED turns **Blue**.
4.  **Testing:** Buyer removes item. 5-minute timer starts. External camera logs buyer position.
5.  **Return:** Buyer puts item back before timer ends.
6.  **Validation:**
    *   Door locks.
    *   Sensors check: Weight == Original? Volume == Original? Vision == Original?
7.  **Result:**
    *   *Pass:* Funds released. LED returns to White.
    *   *Fail:* Funds captured. Seller notified.

---

## 7. Operational & Technical Constraints
*   **Network:** Machine requires stable high-speed internet (4G/5G/WiFi) for video upload, real-time pricing sync, and payment webhooks.
*   **Power:** Continuous power supply required for sensors, lighting, and locks.
*   **Location:** Must be placed in monitored areas (MRT stations) to deter vandalism of the machine itself.
*   **Latency:** Payment-to-unlock latency must be under 3 seconds to prevent user frustration.