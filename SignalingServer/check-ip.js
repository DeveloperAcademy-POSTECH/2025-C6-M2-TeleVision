const os = require('os');
const interfaces = os.networkInterfaces();

console.log('All network interfaces:');
for (const name in interfaces) {
  console.log(`\n${name}:`);
  for (const iface of interfaces[name]) {
    if (iface.family === 'IPv4') {
      console.log(`  ${iface.address} (internal: ${iface.internal})`);
    }
  }
}
