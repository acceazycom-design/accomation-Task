const express = require('express');
const { pool } = require('../config/database');
const { auth, adminOnly } = require('../middleware/auth');

const router = express.Router();

// Log hours manually
router.post('/', auth, async (req, res) => {
  const { task_id, description, hours, date } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO timesheets (user_id, task_id, description, hours, date) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [req.user.id, task_id, description, hours, date || new Date().toISOString().split('T')[0]]
    );
    res.status(201).json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Start timer
router.post('/start', auth, async (req, res) => {
  const { task_id, description } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO timesheets (user_id, task_id, description, hours, start_time) VALUES ($1,$2,$3,0,$4) RETURNING *',
      [req.user.id, task_id, description, new Date()]
    );
    res.status(201).json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Stop timer
router.patch('/:id/stop', auth, async (req, res) => {
  try {
    const endTime = new Date();
    const ts = await pool.query('SELECT * FROM timesheets WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
    if (!ts.rows[0]) return res.status(404).json({ error: 'Timesheet not found' });
    const hours = ((endTime - new Date(ts.rows[0].start_time)) / 3600000).toFixed(2);
    const result = await pool.query(
      'UPDATE timesheets SET end_time=$1, hours=$2 WHERE id=$3 RETURNING *',
      [endTime, hours, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get my timesheets
router.get('/my', auth, async (req, res) => {
  const { from, to } = req.query;
  try {
    let query = `
      SELECT ts.*, t.title as task_title, p.name as project_name
      FROM timesheets ts
      LEFT JOIN tasks t ON ts.task_id = t.id
      LEFT JOIN projects p ON t.project_id = p.id
      WHERE ts.user_id=$1
    `;
    const params = [req.user.id];
    if (from) { params.push(from); query += ` AND ts.date>=$${params.length}`; }
    if (to) { params.push(to); query += ` AND ts.date<=$${params.length}`; }
    query += ' ORDER BY ts.date DESC, ts.created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get all team timesheets (admin)
router.get('/team', auth, adminOnly, async (req, res) => {
  const { from, to, user_id } = req.query;
  try {
    let query = `
      SELECT ts.*, u.name as user_name, u.avatar, t.title as task_title, p.name as project_name
      FROM timesheets ts
      JOIN users u ON ts.user_id = u.id
      LEFT JOIN tasks t ON ts.task_id = t.id
      LEFT JOIN projects p ON t.project_id = p.id
      WHERE 1=1
    `;
    const params = [];
    if (user_id) { params.push(user_id); query += ` AND ts.user_id=$${params.length}`; }
    if (from) { params.push(from); query += ` AND ts.date>=$${params.length}`; }
    if (to) { params.push(to); query += ` AND ts.date<=$${params.length}`; }
    query += ' ORDER BY ts.date DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Weekly summary per member (dashboard)
router.get('/summary', auth, adminOnly, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT u.id, u.name, u.avatar,
        COALESCE(SUM(ts.hours) FILTER (WHERE ts.date >= CURRENT_DATE - INTERVAL '7 days'), 0) as week_hours,
        COALESCE(SUM(ts.hours) FILTER (WHERE date_trunc('month', ts.date) = date_trunc('month', CURRENT_DATE)), 0) as month_hours,
        COUNT(DISTINCT t.id) FILTER (WHERE t.status != 'done') as open_tasks
      FROM users u
      LEFT JOIN timesheets ts ON u.id = ts.user_id
      LEFT JOIN tasks t ON u.id = t.assigned_to
      WHERE u.is_active = true
      GROUP BY u.id, u.name, u.avatar
      ORDER BY week_hours DESC
    `);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
