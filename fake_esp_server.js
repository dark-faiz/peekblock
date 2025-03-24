const express = require("express");
const app = express();
const PORT = 3000;

// Simulated WiFi scan response
app.get("/scan", (req, res) => {
    const fakeData = [
        { "mac": "00:1A:2B:3C:4D:5E", "rssi": -45 },
        { "mac": "11:22:33:44:55:66", "rssi": -60 },
        { "mac": "77:88:99:AA:BB:CC", "rssi": -30 }
    ];
    res.json(fakeData);
});

app.listen(PORT, () => {
    console.log(`ESP Simulation Server running on http://localhost:${PORT}`);
});
