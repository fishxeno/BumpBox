import 'dotenv/config';
import express, { raw, json, urlencoded, static as expressStatic } from 'express';
import { resolve, join } from 'path';
import methodOverride from 'method-override';
import detectObjectRouter from './routes/detectObject.js';
import db from './dbConnection.js';
import Stripe from 'stripe';
import cors from 'cors';
import { setCaptureTrigger, getAndResetCaptureTrigger, getLatestDetection, storeDetection } from './storage.js';

const app = express();
const __dirname = resolve();
//reverse proxy setup + static files
app.use(expressStatic(join(__dirname, "public")));
app.set('trust proxy', true);

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

const createCustomer = async (req, res) => {
    const data = req.body;
    const customer = await stripe.customers.create({
        email: data.email,
    });
    return customer.id;
}

//webhook endpoint for stripe
//update item to sold when payment is successful
app.post('/webhook', raw({ type: 'application/json' }), (req, res) => {
  	console.log(req.rawBody);
  	res.sendStatus(200);
});
app.use(
  cors({
    origin: [
      "http://localhost:5173",
      "http://localhost:8080",
    ],
  })
);
app.use(json());
app.use(urlencoded({ extended: true }));
app.use(methodOverride());
app.use(detectObjectRouter);

// Trigger ESP32 camera capture (called by Flutter app)
app.post('/api/locker/trigger-capture', (req, res) => {
    try {
        const lockerId = req.body.lockerId || 'locker1';
        setCaptureTrigger(lockerId);
        console.log(`[trigger-capture] Capture triggered for ${lockerId}`);
        return res.status(200).json({ success: true, message: 'Capture triggered', lockerId });
    } catch (error) {
        console.error('[trigger-capture] Error:', error.message);
        return res.status(500).json({ error: 'Failed to trigger capture' });
    }
});

// ESP32 polling endpoint to check if capture should be triggered
app.get('/api/locker/capture-trigger', (req, res) => {
    try {
        const result = getAndResetCaptureTrigger();
        if (result.shouldCapture) {
            console.log(`[capture-trigger] ESP32 acknowledged capture trigger for ${result.lockerId}`);
        }
        return res.status(200).json(result);
    } catch (error) {
        console.error('[capture-trigger] Error:', error.message);
        return res.status(500).json({ error: 'Failed to check trigger' });
    }
});

// Get latest detection result (polled by Flutter app)
app.get('/api/detections/latest', (req, res) => {
    try {
        const sinceTimestamp = req.query.since;
        const result = getLatestDetection(sinceTimestamp);
        return res.status(200).json(result);
    } catch (error) {
        console.error('[detections/latest] Error:', error.message);
        return res.status(500).json({ error: 'Failed to fetch detection' });
    }
});

//for esp polling
app.get('/api/item/status', async (req, res) => {
    try {
        const itemId = req.query.itemId;
        const query = `SELECT * FROM items WHERE itemid = ?`;
        const [rows] = await db.execute(query, [itemId]);
        if (rows.length === 0) {
            return res.status(404).json({ error: 'Item not found' });
        }
        if (rows[0].status == 'true') {
            return res.status(200).json({ status: true, message: 'Item is sold' });
        }
        return res.status(200).json({ status: false, message: 'Item is not sold', data: rows[0] });
    } catch (error) {
        console.error('Get item error:', error.stack);
        return res.status(500).json({ error: 'Error fetching item' });
    }
});

// TEST ENDPOINT: Simulate ESP32 detection without hardware
app.post('/api/test/simulate-detection', (req, res) => {
    try {
        const lockerId = req.body.lockerId || 'locker1';
        const itemType = req.body.itemType || 'Headphones';
        
        // Mock detection results based on item type
        const mockDetections = {
            'Headphones': {
                label: 'Headphones',
                category: 'Electronics',
                minPrice: 10,
                maxPrice: 80,
                confidence: 95
            },
            'Laptop': {
                label: 'Laptop',
                category: 'Electronics',
                minPrice: 150,
                maxPrice: 600,
                confidence: 92
            },
            'Smartphone': {
                label: 'Smartphone',
                category: 'Electronics',
                minPrice: 50,
                maxPrice: 400,
                confidence: 88
            },
            'Book': {
                label: 'Book',
                category: 'Books',
                minPrice: 2,
                maxPrice: 15,
                confidence: 85
            },
            'Watch': {
                label: 'Watch',
                category: 'Accessories',
                minPrice: 20,
                maxPrice: 150,
                confidence: 90
            }
        };
        
        const detection = mockDetections[itemType] || mockDetections['Headphones'];
        storeDetection(detection, lockerId);
        
        console.log(`[TEST] Simulated detection: ${detection.label} for ${lockerId}`);
        
        return res.status(200).json({
            success: true,
            message: 'Simulated detection stored',
            detection
        });
    } catch (error) {
        console.error('[TEST] Error:', error.message);
        return res.status(500).json({ error: 'Failed to simulate detection' });
    }
});

Date.prototype.addDays = function(days) {
    var date = new Date(this.valueOf());
    date.setDate(date.getDate() + days);
    return date;
}

function addDaysAndFormat(days, baseDate = new Date()) {
  const date = new Date(baseDate);
  date.setDate(date.getDate() + days);

  const pad = (n) => String(n).padStart(2, '0');

  return (
    date.getFullYear() + '-' +
    pad(date.getMonth() + 1) + '-' +
    pad(date.getDate()) + ' ' +
    pad(date.getHours()) + ':' +
    pad(date.getMinutes()) + ':' +
    pad(date.getSeconds())
  );
}

//create new item endpoint
app.post('/api/item', async (req, res) => {
    try {
            const product = await stripe.products.create({
                name: req.body.item_name,
                description: req.body.description,
                default_price_data: {
                    unit_amount: Math.round(req.body.price * 100), // Convert to cents
                    currency: 'sgd',
                },
            });

            const paymentLink = await stripe.paymentLinks.create({
                line_items: [
                    {
                        price: product.default_price,
                        quantity: 1,
                    },
                ],
            });
            const itemData = req.body;
            const query = `INSERT INTO items (phone, item_name, price, productid, priceid, datetime_expire, paymentLink) VALUES (?, ?, ?, ?, ?, ?, ?)`;
            const [rows] = await db.execute(query, [
                itemData.phone,
                itemData.item_name,
                itemData.price,
                product.id,
                product.default_price,
                addDaysAndFormat(itemData.days),
                paymentLink.url
            ]);
            return res.status(201).json({ message: 'Item created successfully', itemId: rows.insertId, data: rows });
        } catch (error) {
            console.error('Create new item error:', error.stack);
            throw new Error('500', 'Error creating new item');
        }
});

// Start the server
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  	console.log(`Server running on port ${PORT}`);
});
