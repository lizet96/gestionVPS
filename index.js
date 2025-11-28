const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const ENVIRONMENT = process.env.ENVIRONMENT || 'UNKNOWN';

// Middleware
app.use(express.json());

// Rutas
app.get('/', (req, res) => {
  res.json({ 
    message: `🚀 Deployment automático funcionando!`,
    environment: ENVIRONMENT,
    color: ENVIRONMENT === 'blue' ? '🔵 AZUL' : '🟢 VERDE',
    version: '2.0'
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
    { id: 1, name: 'Juan', email: 'juan@example.com' },
    { id: 2, name: 'María', email: 'maria@example.com' },
    { id: 3, name: 'Pedro', email: 'pedro@example.com' }
  ];
  res.json(users);
});

app.post('/api/users', (req, res) => {
  const newUser = req.body;
  res.status(201).json({
    message: 'Usuario creado',
    user: newUser
  });
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
  console.log(`🎨 Ambiente: ${ENVIRONMENT} ${ENVIRONMENT === 'blue' ? '🔵' : '🟢'}`);
});