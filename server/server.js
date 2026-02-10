const express = require('express');
const app = express();
require('dotenv').config();
const db = require('./dbConnection');
const cors = require('cors');
const path = require('path');
const methodOverride = require('method-override');

// const stripePublishKey = process.env.STRIPE_PUBLISHABLE_KEY || undefined;
// const stripeSecretKey = process.env.STRIPE_SECRET_KEY || undefined;
// const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_KEY || undefined;

app.use(methodOverride()); //override method names for older clients
app.use(express.json()); // to parse json form data
app.use(express.urlencoded({ extended: true }));


const __dirname = path.resolve();
//reverse proxy setup + static files
app.use(express.static(path.join(__dirname, "public")));
app.set('trust proxy', true);

app.get('/api/items', (req, res) => {
  res.json({
    items: ['item1', 'item2', 'item3']
  });
});

app.post('/webhook', express.raw({ type: 'application/json' }), (req, res) => {
  console.log(req.rawBody);
  res.sendStatus(200);
});


// Start the server
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});