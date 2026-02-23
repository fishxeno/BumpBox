import "dotenv/config";
import express, {
    raw,
    json,
    urlencoded,
    static as expressStatic,
} from "express";
import { resolve, join } from "path";
import methodOverride from "method-override";
import detectObjectRouter from "./routes/detectObject.js";
import db from "./dbConnection.js";
import Stripe from "stripe";
import cors from "cors";
import { addDaysAndFormat } from "./utils/helperfunctions.js";
import mqtt from "mqtt";

const mqttClient = mqtt.connect("mqtt://broker.hivemq.com");
mqttClient.on("connect", () => {
    console.log("Connected to MQTT broker");
});
mqttClient.on("error", (err) => {
    console.error("MQTT connection error:", err);
});

const app = express();
const __dirname = resolve();
//reverse proxy setup + static files
app.use(expressStatic(join(__dirname, "public")));
app.set("trust proxy", true);

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

let captureTimeout = null;

const scheduleCapture = (paymentIntentId) => {
    captureTimeout = setTimeout(async () => {
        try {
            await stripe.paymentIntents.capture(paymentIntentId);
        } catch (err) {
            console.error("Capture failed:", err);
        }
    }, 5 * 60 * 1000);
}

const cancelCapture = () => {
    if (captureTimeout) { //if capture time out exists, then clear the timeout, then wipe the function
        clearTimeout(captureTimeout);
        captureTimeout = null;
    }
}

//webhook endpoint for stripe
//update item to sold when payment is successful
app.post("/webhook", raw({ type: "application/json" }), async (req, res) => {
    const event = stripe.webhooks.constructEvent(
        req.body,
        req.headers["stripe-signature"],
        process.env.STRIPE_WEBHOOK_KEY,
    );
    if (event.type === "payment_intent.succeeded") {
        // meaning money is charged successfully, update item to sold
        //mysql doesn't want select and update in the same query, so we have to do it in 2 queries
        const [rows] = await db.execute(
            `SELECT * FROM items ORDER BY itemid DESC LIMIT 1`,
        );
        const query = `UPDATE items SET sale_status = 1 WHERE itemid = ?`;
        await db.execute(query, rows[0].itemid);
        await stripe.paymentLinks.update(rows[0].paymentLink, { active: false });

    } else if (event.type === "checkout.session.completed") {
        // meaning checkout is completed, but money is not charged yet, we will capture the payment after 5 minutes
        const session = event.data.object;
        const paymentIntentId = session.payment_intent;
        mqttClient.publish(
            "esp32/door1/alayerofsecurity/unlock",
            JSON.stringify({
                action: "unlock",
                paymentId: paymentIntentId
            })
        );
        scheduleCapture(paymentIntentId);
    }
    res.sendStatus(200);
});

app.get("/return", (req, res) => {
    cancelCapture();
    res.sendStatus(200);
});

app.use(
    cors({
        origin: ["http://localhost:5173", "http://localhost:8080"],
    }),
);
app.use(json());
app.use(urlencoded({ extended: true }));
app.use(methodOverride());
app.use(detectObjectRouter);

//get item, for esp polling, we will only return the latest item, as the esp will only display the latest item
app.get("/api/item", async (req, res) => {
    try {
        const query = `SELECT * FROM items ORDER BY itemid DESC LIMIT 1`;
        const [rows] = await db.execute(query);
        if (rows.length === 0) {
            return res.status(404).json({ error: "Item not found", status: false });
        }
        if (rows[0].sale_status == 1) {
            return res
                .status(200)
                .json({ status: true, message: "Item is sold", data: rows[0] });
        }
        return res.status(200).json({
            status: false,
            message: "Item is not sold",
            data: rows[0],
        });

    } catch (error) {
        console.error("Get items error:", error.stack);
        return res.status(500).json({ error: "Error fetching items" });
    }
});

//capture payment endpoint
app.post("/api/capture", async (req, res) => {
    try {
        const paymentIntentId = req.body.paymentIntentId;
        const paymentIntent =
            await stripe.paymentIntents.capture(paymentIntentId);
        const query = `UPDATE items SET sale_status = 0 WHERE priceid = ?`;
        const [rows] = await db.execute(query, [paymentIntent.payment_method]);
        return res
            .status(200)
            .json({ message: "Payment captured successfully", data: rows });
    } catch (error) {
        console.error("Capture payment error:", error.stack);
        return res.status(500).json({ error: "Error capturing payment" });
    }
});

//create new item endpoint
app.post("/api/item", async (req, res) => {
    try {
        const product = await stripe.products.create({
            name: req.body.item_name,
            description: req.body.description,
            default_price_data: {
                unit_amount: Math.round(req.body.price * 100), // Convert to cents
                currency: "sgd",
            },
        });

        const paymentLink = await stripe.paymentLinks.create({
            payment_intent_data: {
                capture_method: "manual",
            },
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
            paymentLink.url,
        ]);
        return res.status(201).json({
            message: "Item created successfully",
            itemId: rows.insertId,
            data: rows,
        });
    } catch (error) {
        console.error("Create new item error:", error.stack);
        throw new Error("500", "Error creating new item");
    }
});

// Endpoint to edit price of latest item
app.put("/api/item/price", async (req, res) => {
    try {
        const [item] = await db.execute(`SELECT itemid, productid, paymentLink FROM items ORDER BY itemid DESC LIMIT 1`);
        const newPrice = await stripe.prices.create({
            unit_amount: Math.round(req.body.price * 100), // Convert to cents
            currency: "sgd",
            product: item[0].productid,
        });

        const paymentLink = await stripe.paymentLinks.create({
            payment_intent_data: {
                capture_method: "manual",
            },
            line_items: [
                {
                    price: newPrice.id,
                    quantity: 1,
                },
            ],
        });

        const query = `UPDATE items SET price = ?, priceid = ?, paymentLink = ? WHERE itemid = ?`;
        await db.execute(query, [req.body.price, newPrice.id, paymentLink.url, itemId[0].itemid]);
        await stripe.paymentLinks.update(item[0].paymentLink, { active: false });
        const [updatedRows] = await db.execute(`SELECT * FROM items WHERE itemid = ?`, [item[0].itemid]);
        return res.status(200).json({ items: updatedRows });// return new payment link for frontend to update
    } catch (error) {
        console.error("Update item error:", error.stack);
        return res.status(500).json({ error: "Error updating item" });
    }
});


const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
