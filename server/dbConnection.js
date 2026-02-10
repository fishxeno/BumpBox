import { createPool } from "mysql2";

let pool;

export default function initDB() {
  pool = createPool({
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
}