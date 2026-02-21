import 'dotenv/config';
import express, { raw, json, urlencoded, static as expressStatic } from 'express';
import { resolve, join } from 'path';
import methodOverride from 'method-override';
import db from './dbConnection.js';
import Stripe from 'stripe';
import cors from 'cors';

const app = express();
const __dirname = resolve();
//reverse proxy setup + static files
app.use(expressStatic(join(__dirname, "public")));
app.set('trust proxy', true);

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

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

//capture payment endpoint
app.post('/api/capture', async (req, res) => {
    try {
        const paymentIntentId = req.body.paymentIntentId;
        const paymentIntent = await stripe.paymentIntents.capture(paymentIntentId);
        const query = `UPDATE item SET sale_status = 0 WHERE priceid = ?`;
        const [rows] = await db.execute(query, [paymentIntent.payment_method]);
        return res.status(200).json({ message: 'Payment captured successfully', data: rows });
    }
    catch (error) {
        console.error('Capture payment error:', error.stack);
        return res.status(500).json({ error: 'Error capturing payment' });
    }
});

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
                capture_method: 'manual',
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

// Endpoint to edit price of latest item
app.put('/api/item/price', async (req, res) => {
    try {
        const query = `UPDATE item SET price = ? WHERE itemid = (SELECT itemid FROM item ORDER BY itemid DESC LIMIT 1)`;
        const [rows] = await db.execute(query, [req.body.price]);
        return res.status(200).json({ items: rows });
    }
    catch (error) {
        console.error('Update item error:', error.stack);
        return res.status(500).json({ error: 'Error updating item' });
    }
});

// Start the server
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  	console.log(`Server running on port ${PORT}`);
});
