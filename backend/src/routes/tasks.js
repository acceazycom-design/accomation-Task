const express = require('express');
const { pool } = require('../config/database');
const { auth, adminOnly } = require('../middleware/auth');

const router = express.Router();

// Get all tasks (with filters)
router.get('/', auth, async (req, res) => {
  const { status, priority, assigned_to, project_id, sprint_id } = req.query;
  try {
    let query = `
      SELECT t.*, 
        u1.name as assigned_name, u1.avatar as assigned_avatar,
        u2.name as created_name,
        p.name as project_name, s.name as sprint_name
      FROM tasks t
      LEFT JOIN users u1 ON t.assigned_to = u1.id
      LEFT JOIN users u2 ON t.created_by = u2.id
      LEFT JOIN projects p ON t.project_id = p.id
      LEFT JOIN sprints s ON t.sprint_id = s.id
      WHERE 1=1
    `;
    const params = [];
    if (status) { params.push(status); query += ` AND t.status=$${params.length}`; }
    if (priority) { params.push(priority); query += ` AND t.priority=$${params.length}`; }
    if (assigned_to) { params.push(assigned_to); query += ` AND t.assigned_to=$${params.length}`; }
    if (project_id) { params.push(project_id); query += ` AND t.project_id=$${params.length}`; }
    if (sprint_id) { params.push(sprint_id); query += ` AND t.sprint_id=$${params.length}`; }
    query += ' ORDER BY t.created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get my tasks
router.get('/my', auth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT t.*, p.name as project_name, s.name as sprint_name
      FROM tasks t
      LEFT JOIN projects p ON t.project_id = p.id
      LEFT JOIN sprints s ON t.sprint_id = s.id
      WHERE t.assigned_to=$1 ORDER BY t.due_date ASC NULLS LAST
    `, [req.user.id]);
    res.json(result.rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get single task with comments
router.get('/:id', auth, async (req, res) => {
  try {
    const task = await pool.query(`
      SELECT t.*, u1.name as assigned_name, u1.avatar as assigned_avatar, p.name as project_name
      FROM tasks t
      LEFT JOIN users u1 ON t.assigned_to = u1.id
      LEFT JOIN projects p ON t.project_id = p.id
      WHERE t.id=$1
    `, [req.params.id]);
    if (!task.rows[0]) return res.status(404).json({ error: 'Task not found' });
    const comments = await pool.query(`
      SELECT c.*, u.name, u.avatar FROM comments c
      JOIN users u ON c.user_id = u.id
      WHERE c.task_id=$1 ORDER BY c.created_at ASC
    `, [req.params.id]);
    res.json({ ...task.rows[0], comments: comments.rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create task
router.post('/', auth, async (req, res) => {
  const { title, description, priority, assigned_to, project_id, sprint_id, due_date, story_points } = req.body;
  try {
    const result = await pool.query(
      `INSERT INTO tasks (title,description,priority,assigned_to,created_by,project_id,sprint_id,due_date,story_points)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [title, description, priority || 'medium', assigned_to, req.user.id, project_id, sprint_id, due_date, story_points || 0]
    );
    // Create notification for assigned member
    if (assigned_to && assigned_to !== req.user.id) {
      await pool.query(
        'INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)',
        [assigned_to, 'New task assigned', `You have been assigned: ${title}`]
      );
    }
    res.status(201).json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Update task
router.patch('/:id', auth, async (req, res) => {
  const { title, description, status, priority, assigned_to, due_date, story_points, sprint_id } = req.body;
  try {
    const result = await pool.query(
      `UPDATE tasks SET
        title=COALESCE($1,title), description=COALESCE($2,description),
        status=COALESCE($3,status), priority=COALESCE($4,priority),
        assigned_to=COALESCE($5,assigned_to), due_date=COALESCE($6,due_date),
        story_points=COALESCE($7,story_points), sprint_id=COALESCE($8,sprint_id),
        updated_at=NOW()
       WHERE id=$9 RETURNING *`,
      [title, description, status, priority, assigned_to, due_date, story_points, sprint_id, req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ error: 'Task not found' });
    res.json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Delete task (admin only)
router.delete('/:id', auth, adminOnly, async (req, res) => {
  try {
    await pool.query('DELETE FROM tasks WHERE id=$1', [req.params.id]);
    res.json({ message: 'Task deleted' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Add comment to task
router.post('/:id/comments', auth, async (req, res) => {
  try {
    const result = await pool.query(
      'INSERT INTO comments (task_id, user_id, content) VALUES ($1,$2,$3) RETURNING *',
      [req.params.id, req.user.id, req.body.content]
    );
    res.status(201).json(result.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
