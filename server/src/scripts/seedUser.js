require('dotenv').config();
const bcrypt = require('bcryptjs');
const connectDB = require('../config/db');
const User = require('../models/User');

const USERNAME = process.argv[2] || 'Darshan';
const PASSWORD = process.argv[3] || 'Darshan@123';

async function seed() {
  await connectDB();

  const passwordHash = await bcrypt.hash(PASSWORD, 10);
  const user = await User.findOneAndUpdate(
    { username: USERNAME },
    { username: USERNAME, passwordHash },
    { upsert: true, returnDocument: 'after' }
  );

  console.log(`Seeded user "${user.username}" (id: ${user._id})`);
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seed failed', err);
  process.exit(1);
});
