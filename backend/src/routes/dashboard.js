const express = require('express');
const { pool } = require('../config/database');
const { auth } = require('../middleware/auth');

const router = express.Router();

// Main dashboard stats
router.get('/stats', auth, async (req, res) => {
  try {
    const tasks = await pool.query(`
      SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status='in_progress') as in_progress,
        COUNT(*) FILTER (WHERE status='done') as done,
        COUNT(*) FILTER (WHERE status='todo') as todo,
        COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND status != 'done') as overdue
      FROM tasks
    `);
    const hours = await pool.query(`
      SELECT
        COALESCE(SUM(hours) FILTER (WHERE date >= CURRENT_DATE - INTERVAL '7 days'), 0) as week_hours,
        COALESCE(SUM(hours) FILTER (WHERE date_trunc('month', date) = date_trunc('month', CURRENT_DATE)), 0) as month_hours
      FROM timesheets
    `);
    const members = await pool.query('SELECT COUNT(*) as total FROM users WHERE is_active=true');
    const projects = await pool.query("SELECT COUNT(*) as total FROM projects WHERE status='active'");
    res.json({
      tasks: tasks.rows[0],
      hours: hours.rows[0],
      active_members: members.rows[0].total,
      active_projects: projects.rows[0].total
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Team workload
router.get('/workload', auth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT u.id, u.name, u.avatar,
        COUNT(t.id) FILTER (WHERE t.status != 'done') as open_tasks,
        COUNT(t.id) as total_tasks,
        COALESCE(SUM(ts.hours) FILTER (WHERE ts.date >= CURRENT_DATE - INTERVAL '7 days'), 0) as week_hours
      FROM users u
      LEFT JOIN tasks t ON u.id = t.assigned_to
      LEFT JOIN timesheets ts ON u.id = ts.user_id
      WHERE u.is_active = true
      GROUP BY u.id, u.name, u.avatar
      ORDER BY open_tasks DESC
    `);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Recent activity feed
router.get('/activity', auth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 'task_updated' as type, t.title, u.name, u.avatar, t.status, t.updated_at as time
      FROM tasks t JOIN users u ON t.assigned_to = u.id
      WHERE t.updated_at >= NOW() - INTERVAL '24 hours'
      UNION ALL
      SELECT 'hours_logged' as type, tk.title, u.name, u.avatar, ts.hours::text as status, ts.created_at as time
      FROM timesheets ts
      JOIN users u ON ts.user_id = u.id
      LEFT JOIN tasks tk ON ts.task_id = tk.id
      WHERE ts.created_at >= NOW() - INTERVAL '24 hours'
      ORDER BY time DESC LIMIT 20
    `);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Notifications for current user
router.get('/notifications', auth, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Mark notification read
router.patch('/notifications/:id/read', auth, async (req, res) => {
  try {
    await pool.query('UPDATE notifications SET is_read=true WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
    res.json({ message: 'Marked as read' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
