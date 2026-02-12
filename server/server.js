import 'dotenv/config';
import express, { raw, json, urlencoded, static as expressStatic } from 'express';
import { resolve, join } from 'path';
import methodOverride from 'method-override';
import db from './dbConnection.js';

const app = express();
const __dirname = resolve();
//reverse proxy setup + static files
app.use(expressStatic(join(__dirname, "public")));
app.set('trust proxy', true);

app.post('/webhook', raw({ type: 'application/json' }), (req, res) => {
  	console.log(req.rawBody);
  	res.sendStatus(200);
});

app.use(json()); // to parse json form data
app.use(urlencoded({ extended: true }));
app.use(methodOverride()); //override method names for older clients

// app.get('/api/items', (req, res) => {
// 	console.log("Fetching items");
//   res.json({
//     items: ['item1', 'item2', 'item3']
//   });
// });

// router.get('/api/items/:itemId/status', items.getItemStatusById);
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
        return res.status(200).json({ status: false, message: 'Item is not sold' });
    } catch (error) {
        console.error('Get item error:', error.stack);
        return res.status(500).json({ error: 'Error fetching item' });
    }
});

// app.post('/api/items', items.validateData, async (req, res) => {
//     try {
//             const itemData = res.locals.data;
//             const query = `INSERT INTO items (userId, itemname, price, description) VALUES (?, ?, ?, ?)`;
//             const [result] = await db.execute(query, [
//                 itemData.userId,
//                 itemData.itemname,
//                 itemData.price,
//                 itemData.description
//             ]);
//             return result;
//         } catch (error) {
//             console.error('Create new item error:', error.stack);
//             throw new Error('500', 'Error creating new item');
//         }
// });


// Start the server
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  	console.log(`Server running on port ${PORT}`);
});