const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../config/database');
const { auth, adminOnly } = require('../middleware/auth');

const router = express.Router();

// Register (admin creates first account)
router.post('/register', async (req, res) => {
  const { name, email, password, role = 'member' } = req.body;
  try {
    const hash = await bcrypt.hash(password, 10);
    const avatar = name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
    const result = await pool.query(
      'INSERT INTO users (name, email, password, role, avatar) VALUES ($1,$2,$3,$4,$5) RETURNING id,name,email,role,avatar',
      [name, email, hash, role, avatar]
    );
    const user = result.rows[0];
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
    res.status(201).json({ token, user });
  } catch (e) {
    if (e.code === '23505') return res.status(400).json({ error: 'Email already exists' });
    res.status(500).json({ error: e.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const result = await pool.query('SELECT * FROM users WHERE email=$1 AND is_active=true', [email]);
    const user = result.rows[0];
    if (!user || !await bcrypt.compare(password, user.password))
      return res.status(401).json({ error: 'Invalid email or password' });
    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
    res.json({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role, avatar: user.avatar } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get current user profile
router.get('/me', auth, async (req, res) => {
  try {
    const result = await pool.query('SELECT id,name,email,role,avatar,created_at FROM users WHERE id=$1', [req.user.id]);
    res.json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get all team members (admin)
router.get('/team', auth, async (req, res) => {
  try {
    const result = await pool.query('SELECT id,name,email,role,avatar,is_active,created_at FROM users ORDER BY name');
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Invite / create team member (admin only)
router.post('/invite', auth, adminOnly, async (req, res) => {
  const { name, email, role = 'member' } = req.body;
  try {
    const tempPassword = uuidv4().slice(0, 10);
    const hash = await bcrypt.hash(tempPassword, 10);
    const avatar = name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
    const result = await pool.query(
      'INSERT INTO users (name, email, password, role, avatar) VALUES ($1,$2,$3,$4,$5) RETURNING id,name,email,role,avatar',
      [name, email, hash, role, avatar]
    );
    res.status(201).json({ user: result.rows[0], tempPassword, message: 'Team member invited. Share the temp password.' });
  } catch (e) {
    if (e.code === '23505') return res.status(400).json({ error: 'Email already exists' });
    res.status(500).json({ error: e.message });
  }
});

// Deactivate team member (admin only)
router.patch('/team/:id/deactivate', auth, adminOnly, async (req, res) => {
  try {
    await pool.query('UPDATE users SET is_active=false WHERE id=$1', [req.params.id]);
    res.json({ message: 'Member deactivated' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
