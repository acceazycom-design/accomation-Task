require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initDB } = require('./config/database');

const app = express();

app.use(cors({ origin: process.env.FRONTEND_URL || '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', app: 'Accomation.io', time: new Date() }));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/tasks', require('./routes/tasks'));
app.use('/api/timesheets', require('./routes/timesheets'));
app.use('/api/projects', require('./routes/projects'));
app.use('/api/dashboard', require('./routes/dashboard'));

// 404
app.use((req, res) => res.status(404).json({ error: 'Route not found' }));

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;

initDB().then(() => {
  app.listen(PORT, () => console.log(`Accomation.io API running on port ${PORT}`));
}).catch(err => {
  console.error('Failed to initialize database:', err);
  process.exit(1);
});
