const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

exports.login = async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  const user = await User.findOne({ username: username.trim() });
  if (!user) return res.status(401).json({ error: 'Invalid username or password' });

  const match = await bcrypt.compare(password, user.passwordHash);
  if (!match) return res.status(401).json({ error: 'Invalid username or password' });

  const token = jwt.sign({ sub: user._id, username: user.username }, process.env.JWT_SECRET, {
    expiresIn: '30d',
  });

  res.json({
    token,
    user: { id: user._id, username: user.username, name: user.name || null },
  });
};
