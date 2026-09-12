// server/providers/vessels/ais-live.js
import WebSocket from 'ws';

class AisLiveProvider {
  constructor(config) {
    this.url = config.url || 'wss://stream.aisstream.io/v0/stream';
    this.apiKey = config.apiKey;
    this.ws = null;
  }

  // Establishes connection to the maritime stream provider
  connect(boundingBoxes, onMessageCallback) {
    this.ws = new WebSocket(this.url);

    this.ws.on('open', () => {
      console.log('Connected to live AIS stream provider.');
      
      // Subscription message payload required by most AIS providers
      const subscriptionMessage = {
        APIKey: this.apiKey,
        BoundingBoxes: boundingBoxes // e.g. [[[lat, lon], [lat, lon]]]
      };
      
      this.ws.send(JSON.stringify(subscriptionMessage));
    });

    this.ws.on('message', (data) => {
      try {
        const parsedData = JSON.parse(data);
        // Normalize the payload structure into a universal format used by your app
        const normalizedVessel = this.normalize(parsedData);
        onMessageCallback(normalizedVessel);
      } catch (error) {
        console.error('Error parsing AIS stream payload:', error);
      }
    });

    this.ws.on('close', () => {
      console.log('AIS stream connection closed. Attempting reconnect...');
      // Reconnection logic goes here
    });
  }

  // Standardizes varied vendor schemas into your application's unique layout
  normalize(raw) {
    return {
      mmsi: raw.MetaData?.MMSI || raw.mmsi,
      name: raw.Message?.ShipStaticData?.ShipName?.trim() || 'Unknown Vessel',
      latitude: raw.MetaData?.Latitude,
      longitude: raw.MetaData?.Longitude,
      speed: raw.Message?.PositionReport?.SpeedOverGround,
      heading: raw.Message?.PositionReport?.TrueHeading,
      timestamp: new Date()
    };
  }
}

export default AisLiveProvider;
