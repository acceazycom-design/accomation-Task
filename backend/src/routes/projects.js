const express = require('express');
const { pool } = require('../config/database');
const { auth, adminOnly } = require('../middleware/auth');

const router = express.Router();

// Get all projects
router.get('/', auth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT p.*, u.name as created_by_name,
        COUNT(DISTINCT t.id) as total_tasks,
        COUNT(DISTINCT t.id) FILTER (WHERE t.status='done') as done_tasks
      FROM projects p
      LEFT JOIN users u ON p.created_by = u.id
      LEFT JOIN tasks t ON p.id = t.project_id
      GROUP BY p.id, u.name ORDER BY p.created_at DESC
    `);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create project
router.post('/', auth, async (req, res) => {
  const { name, description } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO projects (name, description, created_by) VALUES ($1,$2,$3) RETURNING *',
      [name, description, req.user.id]
    );
    res.status(201).json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Update project
router.patch('/:id', auth, async (req, res) => {
  const { name, description, status } = req.body;
  try {
    const result = await pool.query(
      'UPDATE projects SET name=COALESCE($1,name), description=COALESCE($2,description), status=COALESCE($3,status) WHERE id=$4 RETURNING *',
      [name, description, status, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get sprints for a project
router.get('/:projectId/sprints', auth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT s.*,
        COUNT(t.id) as total_tasks,
        COUNT(t.id) FILTER (WHERE t.status='done') as done_tasks,
        COALESCE(SUM(t.story_points),0) as total_points,
        COALESCE(SUM(t.story_points) FILTER (WHERE t.status='done'),0) as done_points
      FROM sprints s
      LEFT JOIN tasks t ON s.id = t.sprint_id
      WHERE s.project_id=$1
      GROUP BY s.id ORDER BY s.start_date DESC
    `, [req.params.projectId]);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create sprint
router.post('/:projectId/sprints', auth, async (req, res) => {
  const { name, start_date, end_date } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO sprints (project_id, name, start_date, end_date) VALUES ($1,$2,$3,$4) RETURNING *',
      [req.params.projectId, name, start_date, end_date]
    );
    res.status(201).json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
