import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

import authRoutes from './routes/auth.routes.js';
import collegeRoutes from './routes/college.routes.js';
import programRoutes from './routes/program.routes.js';
import attendanceRoutes from './routes/attendance.routes.js';
import studentRoutes from './routes/student.routes.js';
import behaviourRoutes from './routes/behaviour.routes.js';
import materialRoutes from './routes/material.routes.js';
import announcementRoutes from './routes/announcement.routes.js';
import analyticsRoutes from './routes/analytics.routes.js';
import appVersionRoutes from './routes/appVersion.routes.js';
import auditRoutes from './routes/audit.routes.js';
import { adminRouter } from './routes/admin.routes.js';
import trainerRoutes from './routes/trainer.routes.js';
import courseRoutes from './routes/course.routes.js';
import reportRoutes from './routes/report.routes.js';
import quizRoutes from './routes/quiz.routes.js';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 5000;

// Security & Middleware
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);

app.use(
  cors({
    origin: '*', // Allow Flutter Android emulator (10.0.2.2), Flutter Web, and Vite Admin Panel
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: '*',
  })
);

app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true, limit: '20mb' }));

// Static files (Logos, banners, materials)
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Health check endpoint
app.get('/api/health', (_req, res) => {
  res.json({
    status: 'HEALTHY',
    service: 'Cognito Tech Hub Backend API',
    company: 'Cognito Insights Private Limited',
    tenants: ['KITS_DIVILI', 'ADARSH'],
    timestamp: new Date(),
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/colleges', collegeRoutes);
app.use('/api', programRoutes); // /programs, /batches, /sessions
app.use('/api/attendance', attendanceRoutes);
app.use('/api/students', studentRoutes);
app.use('/api/behaviour', behaviourRoutes);
app.use('/api/materials', materialRoutes);
app.use('/api/announcements', announcementRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/app', appVersionRoutes);
app.use('/api/audit', auditRoutes);
app.use('/api/admin', adminRouter);
app.use('/api/trainers', trainerRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/quizzes', quizRoutes);

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Global error handler
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled Server Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
  });
});

app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`\n======================================================`);
  console.log(`🚀 Cognito Tech Hub Multi-Tenant API Engine Started`);
  console.log(`🌐 Server running on 0.0.0.0:${PORT}`);
  console.log(`📱 Physical Phone Wi-Fi URL: http://192.168.6.201:${PORT}`);
  console.log(`📱 Android Emulator URL: http://10.0.2.2:${PORT}`);
  console.log(`🏢 Multi-Tenant Database: PostgreSQL (Port 5433)`);
  console.log(`======================================================\n`);
});

export default app;
