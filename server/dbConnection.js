const mysql = require('mysql2');

const db = mysql
  .createPool({
    database: 'bumpbox',
    host: process.env.MYSQL_HOST,
    port: process.env.MYSQL_PORT,
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    timezone: "+00:00",
}).promise()

module.exports = db;
