const io = require("socket.io-client");

const backendUrl = "https://sheildai-flutter.onrender.com";

// Simulate Device A (Victim)
const socketA = io(backendUrl, { transports: ["websocket"], query: { phone: "1111111111" } });

// Simulate Device B (Receiver)
const socketB = io(backendUrl, { transports: ["websocket"], query: { phone: "2222222222" } });

socketA.on("connect", () => {
    console.log("Device A connected:", socketA.id);
    // Send location
    socketA.emit("update_location", { lat: 10.0, lon: 10.0, phone: "1111111111" });
});

socketB.on("connect", () => {
    console.log("Device B connected:", socketB.id);
    // Send location nearby
    socketB.emit("update_location", { lat: 10.001, lon: 10.001, phone: "2222222222" });
});

socketB.on("sentinel_alert", (data) => {
    console.log("Device B RECEIVED sentinel_alert:", data);
});

socketB.on("emergency_nearby", (data) => {
    console.log("Device B RECEIVED emergency_nearby:", data);
});

socketA.on("sentinel_alert", (data) => {
    console.log("Device A RECEIVED sentinel_alert:", data);
});

setTimeout(() => {
    console.log("Device A triggering SOS...");
    socketA.emit("sos_alert", {
        sosId: "sos_123",
        userId: "1111111111",
        name: "Victim A",
        latitude: 10.0,
        longitude: 10.0,
        message: "Help me!"
    });
}, 2000);

setTimeout(() => {
    console.log("Test finished.");
    process.exit(0);
}, 5000);
