const express = require('express');
const cors = require('cors');
const app = express();
const port = 3000;

// Enable CORS for all origins (simple usage)
const corsOptions = {
  origin: 'http://localhost:3001', // Replace with your client-side origin
  optionsSuccessStatus: 200 // some legacy browsers (IE11, various SmartTVs) choke on 204
};

app.use(cors(corsOptions));

// Define a sample route
app.get('/api/data', (req, res) => {
  res.json({
    message: 'Hello from the CORS-enabled server!'
  });
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});