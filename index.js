const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const ENVIRONMENT = process.env.ENVIRONMENT || 'UNKNOWN';
const log = (...args) => console.log('[APP]', ...args);

// Middleware
app.use(express.json());

// Rutas
app.get('/', (req, res) => {
  res.json({
    message: 'Servicio activo con estrategia Blue-Green',
    environment: ENVIRONMENT,
    color: ENVIRONMENT === 'blue' ? 'AZUL 🔷' : 'VERDE 🟩',
    version: '2.1'
  });
});

app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK',
    environment: ENVIRONMENT,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

app.get('/api/users', (req, res) => {
  const users = [
    { id: 1, name: 'Luz', email: 'luz@example.com' },
    { id: 2, name: 'Diego', email: 'diego@example.com' },
    { id: 3, name: 'Sofia', email: 'sofia@example.com' }
  ];
  res.json(users);
});

app.post('/api/users', (req, res) => {
  const newUser = req.body;
  res.status(201).json({
    message: 'Usuario registrado',
    user: newUser
  });
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
  log(`Servidor iniciado en puerto ${PORT}`);
  log(`Entorno: ${ENVIRONMENT} ${ENVIRONMENT === 'blue' ? '🔷' : '🟩'}`);
});