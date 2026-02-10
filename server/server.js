import 'dotenv/config';
import express, { raw, json, urlencoded, static as expressStatic } from 'express';
import { resolve, join } from 'path';
import methodOverride from 'method-override';
import { createPool } from "mysql2";

const app = express();
const __dirname = resolve();
//reverse proxy setup + static files
app.use(expressStatic(join(__dirname, "public")));
app.set('trust proxy', true);

console.log(
	  `DB HOST: ${process.env.MYSQL_HOST}, PORT: ${process.env.MYSQL_PORT}, USER: ${process.env.MYSQL_USER}`
)

// Database connection
const pool = createPool({
	database: 'bumpbox',
    host: process.env.MYSQL_HOST,
    port: process.env.MYSQL_PORT,
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    timezone: "+00:00",
    connectionLimit: 5
  });

  pool.getConnection((err) => {
    if (err) {
      	console.error("DB connection failed:", err);
    } else {
      	console.log("DB connected");
    }
  });

app.post('/webhook', raw({ type: 'application/json' }), (req, res) => {
  	console.log(req.rawBody);
  	res.sendStatus(200);
});


app.use(json()); // to parse json form data
app.use(urlencoded({ extended: true }));
app.use(methodOverride()); //override method names for older clients

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