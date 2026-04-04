# PROJECT REQUIREMENTS DOCUMENT (PRD)

**Project Name:** BumpBox  
**Version:** 2.0  
**Status:** Development / Pilot Phase  
**Last Updated:** April 4, 2026  
**Document Owner:** BumpBox Team

---

## EXECUTIVE SUMMARY

### Project Overview
BumpBox is a smart vending locker system designed to automate the sale of second-hand items with high convenience for sellers and dynamic pricing mechanisms for buyers. Located in high-traffic areas (business parks), it allows busy professionals to "drop and forget" items while providing buyers with a secure, test-before-you-buy experience.

### Tagline
**"Drop. Forget. Get Paid."**

### Problem Statement
Singapore's recommerce market is projected to reach USD 3.77 billion by 2029 (12.3% CAGR), but existing peer-to-peer platforms create significant friction:
- **Sellers** waste hours managing chats, negotiations, no-shows, and coordinating meetups
- **Buyers** fear scams, can't inspect items, and lack trust in condition descriptions
- Despite high demand for sustainable, affordable second-hand goods, current solutions fail on convenience and security

**Design Challenge:** How might we enable frictionless selling for busy professionals who want to declutter but hate the chat-negotiate-meetup cycle?

### Solution
BumpBox deploys 10-locker smart clusters at high-traffic transit and business hubs. Sellers reserve a locker, drop their item, and walk away. AI-powered computer vision assesses condition and suggests pricing. Buyers discover items physically or via app, purchase via Stripe, and optionally test items in a secure 5-minute window before finalizing.

### Target Market
- **Primary Users:** Busy professionals and students aged 22-35 in Singapore
- **Beachhead Locations:** Paya Lebar Quarter, one-north, Changi Business Park
- **Product Categories:** Consumer electronics (phones, tablets, audio), accessories, small gadgets

---

## MARKET CONTEXT & OPPORTUNITY

### Market Size & Growth
- Singapore recommerce market: **USD 3.77 billion by 2029** (CAGR 12.3%)
- Gen Z & Millennials are primary drivers, seeking value + sustainability + convenience
- 75% of Singapore Gen Z willing to pay premium for convenience
- 68% rely on peer reviews and trust signals for purchase decisions

### Competitive Landscape
| Platform | Strengths | Weaknesses |
|----------|-----------|------------|
| **Carousell** | Large user base, wide selection | Time-consuming chats, scams, meetup friction |
| **Carousell Certified** | Trust program, SingPost drop-off | Still requires seller effort, limited categories |
| **Pick Network / 7-Eleven** | Delivery convenience | Parcel service only, not discovery or testing |
| **Facebook Marketplace** | Social integration | Same meetup friction, scam prevalence |

**BumpBox Differentiation:**
1. Physical discovery at commute hubs (not just online listings)
2. Zero seller effort after drop-off (AI handles pricing)
3. Test-before-buy with fraud protection (digital twin verification)
4. Dynamic pricing creates urgency (FOMO from time decay + demand signals)

---

## USER RESEARCH FINDINGS

### Methodology
- Interviews with 15+ hostel residents and young professionals
- Pain point analysis from Carousell/Facebook Marketplace users
- Observational research on second-hand buying behavior

### Key Insights

**Finding 1: Older Professionals (Time-Poor)**
> "It's confusing to sell on online marketplaces. I'd rather leave it to my kids than spend an afternoon researching prices, taking photos, and writing descriptions."

**Finding 2: Younger Professionals (Clutter from Freebies)**
> "I'm not hoarding because I want to—I have spare electronics from credit card bonuses, telco promotions, or buying the wrong part."

**Finding 3: Value Recovery > Profit Maximization**
> "I don't care how much this sells for, but I don't want to give it away for free. I just want to retrieve some value without the hassle."

### User Personas

#### Persona 1: The Busy Professional (Seller)
- **Demographics:** 25-35 years old, working in CBD/business park
- **Goal:** Get rid of unused items and make money without hassle
- **Pain Points:** No time for messaging, scheduling, meetups, negotiating
- **Behavior:** Wants to drop the item and receive funds via PayNow automatically

#### Persona 2: The Commuter/Deal Hunter (Buyer)
- **Demographics:** 22-30 years old, tech-savvy student/young professional
- **Goal:** Find discounted second-hand goods while commuting
- **Pain Points:** Fear of buying defective goods, wants to verify condition
- **Behavior:** Browses app or physical locker, impulsive buying if price is right, values testing

---

## SOLUTION ARCHITECTURE

### System Overview
Three-tier architecture: Hardware Layer → Backend (AWS) → Frontend (App + Kiosk)

### 3.1 HARDWARE LAYER

**ESP32-S3 Microcontroller (Main Brain)**
- Controls solenoid locks, sensors, and lighting
- Communicates with backend via WiFi/4G
- Manages local state and polling cycles

**Components:**
- **ESP-CAM:** High-resolution camera for item scanning and condition assessment
- **Weight Sensors (Load Cell):** Detects item presence, creates density profile for fraud prevention
- **Solenoid Locks:** Electronic control for door locking/unlocking
- **LED Strips:** Visual feedback
  - Green: Recently price-dropped
  - Blue: Testing in progress
  - White: Available
  - Pulsing: Auction ending soon
- **PIR/Heat Sensors:** Detects user dwell time for dynamic pricing
- **Magnetic Door Sensors:** Confirms door fully closed

**Physical Structure:**
- Body: 3D-printed components with vending machine structural frame
- Doors: Transparent acrylic sheets for physical browsing
- Display: LCD screen or tablet interface for kiosk UI

### 3.2 BACKEND (AWS)

**Database:**
- Stores item states, digital twins (weight hash, image hash, condition grade)
- Tracks payment status, capture state, door lock state

**AI Engine:**
- **Google Vision API:** Object recognition, brand identification, condition assessment
- Converts images → categories → price estimates
- Fraud detection: compares return scans to original digital twin

**Dynamic Pricing Algorithm:**
- **Inputs:**
  - Time remaining (7-day countdown → time-decay pricing)
  - Physical sensor feeds (dwell time → surge pricing)
  - Online analytics (clicks, views → demand-based surge)
- **Outputs:** Real-time price updates pushed to frontend

**Payment Gateway (Stripe):**
- Pre-authorization for test-before-buy
- Webhook listeners trigger door unlock on payment success
- PayNow integration for seller payouts

### 3.3 FRONTEND

**Mobile App (Seller & Buyer):**
- Reserve locker slot
- Input item details, floor price, listing duration, PayNow number
- Browse inventory by location
- Activity tracking (clicks/views feed pricing algorithm)
- Unlock locker via app

**Kiosk UI (On-site Touch Screen):**
- Browse physical locker inventory
- Card terminal / QR code payment
- Immediate purchase flow for walk-up buyers
- Shows dynamic price updates

**Dashboard (Admin/Operator):**
- Monitor item states across all machines
- Track revenue, transaction volume
- Manage inventory and troubleshoot issues

---

## FUNCTIONAL REQUIREMENTS

### 4.1 DYNAMIC PRICING ENGINE

**Automated Condition-Based Pricing:**
1. Computer vision detects scratches, wear, discoloration
2. Weight sensors confirm authenticity and completeness
3. System generates recommended starting price (Excellent/Good/Fair/Poor grade)
4. Price balanced against seller's floor price

**Time-Decay Pricing:**
- Price decreases gradually over 7-day listing period
- Ensures inventory turnover

**Interest-Based Surge Pricing (FOMO Layer):**
- **Triggers:**
  - Physical: Sensors detect person standing in front of locker >15 seconds
  - Online: Spike in app clicks, page views, wishlist adds
- **Mechanism:** Price increases immediately by 5-10%
- **Cooldown:** Price reverts to time-decay baseline when interest subsides

**Seller Inputs:**
- Set minimum acceptable price (floor price)
- Choose listing duration (up to 7 days)
- Do NOT set active listing price

### 4.2 INVENTORY & LISTING MANAGEMENT

**Listing Duration:** Maximum 7 days

**Unsold Item Workflow (Day 7):**
1. Extend: Pay fee to keep listed
2. Auction: 24-hour auction with no reserve price
3. Thrift Export: Sell to BumpBox partners for nominal fee (liquidation)
4. Donate: Send to charity
5. Return: Seller retrieves item

### 4.3 TEST-BEFORE-BUY SYSTEM

**Flow:**
1. **Pre-Authorization:** Buyer requests "Test" → Stripe places hold for full amount
2. **Unlock Timer:** Locker opens, 5-minute countdown starts, LED turns blue
3. **Buyer Monitoring:** External cameras track buyer in vicinity
4. **Return Validation:**
   - Item returned within 5 mins → System scans weight + vision
   - **Pass (matches original):** Card hold released, item re-listed
   - **Fail (damaged/swapped):** Card charged full amount, seller notified
5. **Keep (5 mins elapsed):** Transaction finalized automatically

### 4.4 PAYMENT SYSTEM

**Buyer:**
- Stripe integration (Credit/Debit/Apple Pay)
- Supports immediate capture or pre-auth holds

**Seller:**
- PayNow integration (Singapore standard)
- Payout triggered after successful sale (with waiting period for dispute window)

### 4.5 SECURITY & FRAUD PREVENTION (DIGITAL TWIN)

**At Ingestion (Seller Drop-off):**
- Video recording of seller placing item
- High-resolution photos from multiple angles
- Weight + volumetric scan creates density profile
- Image hash stored in database

**During Test-Before-Buy:**
- External camera monitors buyer
- 5-minute timer enforced
- No part-swapping allowed

**At Return Validation:**
- Re-scan weight, volume, visual surface
- Compare to original digital twin
- Anomaly detection prevents "sandbag for laptop" swaps via density checks

---

## USER FLOWS

### 5.1 SELLER FLOW (DROP-OFF)

1. **Reservation:** Seller inputs item info and floor price on app → reserves locker
2. **Arrival:** Seller arrives at machine, scans QR code to identify session
3. **Verification:** Machine initiates recording
4. **Deposit:** Door opens → Seller places item inside
5. **Scanning:** Machine locks door → Weight scan + Camera captures high-res photos
6. **Confirmation:** Digital twin created → Item goes live on app/kiosk
7. **Sale:** When sold, seller receives PayNow payout automatically

### 5.2 BUYER FLOW (DIRECT PURCHASE)

1. **Browse:** Physical (at locker) or Digital (app)
   - Physical presence detected by sensors → price surge
2. **Pay:** Buyer selects item → Stripe processes payment
3. **Process:** Webhook triggers backend → Backend sends unlock command to ESP32
4. **Collection:** Solenoid releases, door pops open → Buyer retrieves item
5. **Complete:** Door closed sensor confirms → Transaction marked complete

### 5.3 BUYER FLOW (TEST-BEFORE-BUY)

1. **Request:** Buyer selects "Test Item"
2. **Pre-Auth:** Stripe places hold on funds
3. **Unlock:** Door opens, LED turns blue, 5-minute timer starts
4. **Testing:** Buyer removes item, external camera logs position
5. **Return:** Buyer puts item back before timer ends
6. **Validation:** Door locks → Sensors check weight/volume/vision against digital twin
7. **Result:**
   - **Pass:** Funds released, LED returns to white, item re-listed
   - **Fail:** Funds captured, seller notified, transaction complete

---

## TECHNICAL SPECIFICATIONS

### Hardware
- **Microcontroller:** ESP32-S3
- **Camera:** ESP-CAM (internal high-res)
- **Sensors:** Load cell, PIR/heat, magnetic door switch
- **Actuators:** Solenoid locks, LED strips
- **Display:** LCD touchscreen or tablet
- **Connectivity:** WiFi/4G/5G for real-time communication

### Software Stack
- **Backend:** Node.js or Python (AWS-hosted)
- **Database:** PostgreSQL or MongoDB
- **AI/ML:** Google Vision API, custom pricing model
- **Payments:** Stripe API, PayNow integration
- **Mobile App:** React Native or Flutter
- **Kiosk:** Web-based dashboard (HTML/JS)

### Performance Requirements
- **Payment-to-unlock latency:** <3 seconds
- **Network:** Stable high-speed internet (4G/5G/WiFi) for video upload, real-time pricing sync
- **Power:** Continuous supply for 24/7 operation
- **Uptime:** 99%+ availability target

---

## BUSINESS MODEL & UNIT ECONOMICS

### Revenue Model
- **Commission:** 10-15% per successful sale
- **No listing fees** for sellers
- **Future revenue streams:** Premium placements, featured listings, bulk seller partnerships

### Cost Structure (Per 10-Locker Cluster)

| Cost Component | Amount (S$/month) | Notes |
|----------------|------------------|-------|
| **Rent** | 200-700 | Varies by location (low-rent site to prime MRT/CBD) |
| **Hardware Depreciation** | 200 | S$12k amortized over 5 years |
| **Maintenance** | 10 | S$100/month shared across 10 lockers |
| **Insurance** | 50-100 | S$600-1,200/year for unattended vending machine |
| **Other Ops** | 80 | Electricity, connectivity, cloud backend |
| **Total Fixed Cost** | **540-1,090** | Depends on location tier |

### Breakeven Analysis

**Assumptions:**
- Average basket: S$100
- Commission: 12%
- Gross profit per transaction: S$12

**Breakeven Transactions per Month:**

| Location Type | Fixed Cost | Breakeven (sales/month) | Breakeven (sales/day) |
|---------------|-----------|------------------------|---------------------|
| Low-rent site | S$565 | 45-48 | **1.5** |
| Mid-rent hub (PLQ, one-north) | S$815 | 60-68 | **2.0** |
| Prime MRT/CBD | S$1,065 | 75-89 | **2.5** |

**Viability Assessment:**
High-traffic MRT and business-park sites can realistically achieve 2-3 sales per day per machine cluster (60-90 sales/month), making mid-tier locations economically viable.

---

## GO-TO-MARKET STRATEGY

### 4-Month Pilot Timeline (Baby Shark Fund)

**Month 1 (March 2026): Setup**
- Finalize design, target locations, landlord MoUs
- Order hardware components
- Owner: Partnerships & BizDev

**Month 2 (April 2026): Build & Test**
- Build and test prototype (hardware + core software) in lab
- Validate ESP32 → Backend → Stripe integration
- Owner: Hardware & Systems, Backend

**Month 3 (May 2026): Soft Launch**
- Install in first site (Paya Lebar Quarter or one-north)
- Seed inventory with 10-15 initial items
- Soft-launch pilot with early adopters
- Owner: Product & Operations

**Month 4 (June 2026): Optimize & Scale**
- Optimize pricing algorithm based on transaction data
- Measure conversion rates, days-to-sell, user satisfaction
- Prepare post-fund scaling plan
- Owner: Data & Strategy

**Beyond 4 Months:**
- Expand to 2-3 best-performing sites
- Explore co-funding with landlords/industry partners
- Test additional categories (fashion accessories, books, etc.)

### Success Metrics (4-Month Pilot)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Items rehomed | 300+ | Meaningful e-waste diversion |
| Transactions completed | 90+ | ~3 sales/day across pilot |
| Conversion rate | 25%+ | % of listed items that sell |
| Average days-to-sell | <5 days | Inventory turnover speed |
| Seller NPS | 40+ | Net Promoter Score |
| Buyer NPS | 50+ | Trust and satisfaction |

---

## MVP APPROACH: HOSTEL PROOF-OF-CONCEPT

### Pre-Pilot Validation (Manual MVP)

**Objective:** Validate core assumptions before building full automation

**Setup:**
- Single acrylic box with combination lock (S$30-50)
- Telegram channel for listings
- Manual coordination of drop-offs, pricing, payments

**Success Criteria (4 Weeks):**
- 15+ transactions completed
- 30%+ repeat sellers
- <5 hours/week manual effort
- Positive user feedback (NPS >20)

**Decision Gates:**
- **Week 1:** 3+ items listed, 1+ inquiry → Continue
- **Week 2:** 5+ total sales, 1+ repeat seller → Scale
- **Week 3:** 10+ total sales, clear bottlenecks identified → Plan automation
- **Week 4:** 15+ total sales, strong feedback → Build automated system

**Automation Triggers:**
- Manual work >5 hours/week
- Same steps repeated 80%+ of time
- Users asking "Can I just unlock it myself?"

---

## DESIGN & AI INTEGRATION

### Design Principles

**User Experience:**
- Human-centered seller/buyer journeys optimized for MRT/business-park context
- Locker UI and app flows: <30-second interactions
- Visual feedback via color, lighting, messaging (price drops, auctions, testing mode)

**Physical Design:**
- Transparent acrylic doors for discovery
- Compact 10-locker footprint suitable for transit hubs
- LED lighting creates "micro-thrift store" browsing experience

### AI Integration

**Computer Vision:**
- Recognize item type, brand, model
- Grade cosmetic condition (scratches, wear) under controlled lighting
- Generate condition score (Excellent/Good/Fair/Poor)

**Pricing Engine:**
- Inputs: Condition grade + seller floor price + time decay + demand signals
- Outputs: Real-time price recommendations
- Learning: LLMs used to explore pricing rules and simulate scenarios during development

**Fraud Detection:**
- Weight + image comparison for test-before-buy returns
- Anomaly detection prevents part swaps

---

## TEAM & ROLES

| Name | Role | Responsibilities |
|------|------|------------------|
| **Owen** | Software, ESP/Frontend | ESP32 firmware, kiosk UI, sensor integration |
| **Ati** | Hardware & Electronics | Physical design, electronics assembly, installation |
| **Wei Yu** | Software, Backend | AWS infrastructure, database, API, webhooks |
| **Abhishek** | Software, CV/AI | Computer vision, condition grading, pricing algorithm |
| **Elise** | Designer, UI/UX | User flows, app design, branding, visual identity |

---

## RISKS & MITIGATION

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Low transaction volume** | Medium | High | Start with proven high-demand categories; manual MVP validation first |
| **Theft or vandalism** | Medium | Medium | Place in monitored areas; log all access; insurance coverage |
| **CV misgrading items** | Medium | Medium | Human review for first 50 transactions; continuous model improvement |
| **Landlord reluctance** | Medium | High | Partner with forward-thinking sites; offer revenue share; pilot data as proof |
| **Regulatory issues** | Low | High | Consult legal on second-hand goods regulations; obtain proper permits |
| **Test-before-buy fraud** | Low | Medium | Digital twin validation; pre-authorization holds; external monitoring |

---

## SUCCESS CRITERIA & NEXT MILESTONES

### Phase 1: Hostel MVP (Weeks 1-4)
✅ 15+ transactions  
✅ 30%+ repeat sellers  
✅ Positive user feedback (NPS >20)  
✅ Clear automation opportunities identified  

### Phase 2: Automated Pilot (Months 1-4, Baby Shark Fund)
✅ 90+ transactions across 1-2 locations  
✅ 300+ items rehomed  
✅ Unit economics validated (breakeven achieved or clear path)  
✅ Landlord interest for expansion  
✅ Strong seller/buyer NPS (40+/50+)  

### Phase 3: Scale & Expand (Post-Fund, Months 5-12)
- Deploy 5-10 clusters across best-performing sites
- Expand product categories (fashion, books, sports equipment)
- Explore B2B partnerships (corporate decluttering, electronics trade-in)
- Seek Series Seed funding for regional expansion

---

## APPENDICES

### A. Pricing Guide (Typical Hostel/MRT Items)

| Item | Floor Price | List Price | Sell Speed |
|------|------------|-----------|-----------|
| AirPods Gen 2 | S$50 | S$65 | Very Fast |
| Phone charger (original) | S$8 | S$12 | Fast |
| Wireless mouse | S$8 | S$12 | Fast |
| Nintendo Switch games | S$30 | S$40 | Very Fast |
| Power bank (10,000mAh) | S$15 | S$22 | Fast |
| Used textbook | S$20 | S$28 | Medium |

### B. Competitor Analysis Summary

**Carousell:** Largest user base but high friction (chats, meetups, scams)  
**Carousell Certified:** Trust layer but still requires seller effort  
**Pick Network:** Delivery-only, not discovery or testing  
**7-Eleven Drop-off:** Parcel locker, not second-hand marketplace  

**BumpBox Moat:** Physical discovery + AI pricing + test-before-buy in one integrated experience

### C. Market Research Sources

- Singapore Recommerce Market Report 2025 (Yahoo Finance, CAGR 12.3%)
- Gen Z Consumer Behavior Study (75% willing to pay for convenience)
- Carousell User Complaints (Reddit, Straits Times scam reports)
- Vending Machine Business Guides (insurance, rent, maintenance benchmarks)

---

## DOCUMENT REVISION HISTORY

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Feb 27, 2026 | Initial draft with core concept | Team |
| 1.1 | Mar 5, 2026 | Added system architecture diagram | Owen, Wei Yu |
| 2.0 | Apr 4, 2026 | Comprehensive PRD with unit economics, MVP approach, Baby Shark Fund alignment | Full Team |

---

**END OF DOCUMENT**

For questions or updates, contact: [Team Lead Email/Telegram]

