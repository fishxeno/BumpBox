import 'dotenv/config';
import express, { raw, json, urlencoded, static as expressStatic } from 'express';
import { resolve, join } from 'path';
import methodOverride from 'method-override';

// const stripePublishKey = process.env.STRIPE_PUBLISHABLE_KEY || undefined;
// const stripeSecretKey = process.env.STRIPE_SECRET_KEY || undefined;
// const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_KEY || undefined;

const app = express();

app.post('/webhook', raw({ type: 'application/json' }), (req, res) => {
  console.log(req.rawBody);
  res.sendStatus(200);
});


app.use(json()); // to parse json form data
app.use(urlencoded({ extended: true }));
app.use(methodOverride()); //override method names for older clients

const __dirname = resolve();
//reverse proxy setup + static files
app.use(expressStatic(join(__dirname, "public")));
app.set('trust proxy', true);

import initDB from '../server/dbConnection.js';
initDB();


app.get('/api/items', (req, res) => {
  res.json({
    items: ['item1', 'item2', 'item3']
  });
});




// Start the server
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});