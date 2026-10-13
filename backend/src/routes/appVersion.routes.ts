import { Router, Response } from 'express';
import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';

const router = Router();

// 1. App Version Check (Public - called by Flutter app at launch)
router.get('/version', async (req, res: Response): Promise<void> => {
  try {
    const platform = (req.query.platform as string) || 'android';
    const clientVersion = (req.query.currentVersion as string) || '1.0.0';

    const result = await pool.query(
      'SELECT * FROM app_versions WHERE platform = $1',
      [platform.toLowerCase()]
    );

    if (result.rows.length === 0) {
      res.json({
        latestVersion: '1.2.0',
        minimumVersion: '1.0.0',
        updateAvailable: false,
        forceUpdate: false,
        releaseNotes: ['Routine performance improvements and bug fixes.'],
        downloadUrl: 'http://localhost:5000/updates/cognito-techhub-release.apk',
      });
      return;
    }

    const row = result.rows[0];

    // Simple semver comparison helper
    const parseVer = (v: string) => v.split('.').map((n) => parseInt(n) || 0);
    const [cMajor, cMinor, cPatch] = parseVer(clientVersion);
    const [lMajor, lMinor, lPatch] = parseVer(row.latest_version);
    const [mMajor, mMinor, mPatch] = parseVer(row.minimum_version);

    const clientNum = cMajor * 10000 + cMinor * 100 + cPatch;
    const latestNum = lMajor * 10000 + lMinor * 100 + lPatch;
    const minimumNum = mMajor * 10000 + mMinor * 100 + mPatch;

    const updateAvailable = clientNum < latestNum;
    const forceUpdate = row.force_update || clientNum < minimumNum;

    res.json({
      latestVersion: row.latest_version,
      minimumVersion: row.minimum_version,
      updateAvailable,
      forceUpdate,
      releaseNotes: row.release_notes || [],
      downloadUrl: row.download_url,
      serverTime: new Date(),
    });
  } catch (error) {
    console.error('App version check error:', error);
    res.status(500).json({ error: 'Failed to retrieve app version status.' });
  }
});

// 2. Update App Version Policy (Super Admin only)
router.put('/version', authenticateToken, requireRole('SUPER_ADMIN'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { platform = 'android', latestVersion, minimumVersion, forceUpdate, releaseNotes, downloadUrl } = req.body;
    if (!latestVersion || !minimumVersion) {
      res.status(400).json({ error: 'Latest version and minimum version are required.' });
      return;
    }

    const result = await pool.query(
      `INSERT INTO app_versions (platform, latest_version, minimum_version, force_update, release_notes, download_url, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
       ON CONFLICT (platform) DO UPDATE SET
         latest_version = EXCLUDED.latest_version,
         minimum_version = EXCLUDED.minimum_version,
         force_update = EXCLUDED.force_update,
         release_notes = EXCLUDED.release_notes,
         download_url = EXCLUDED.download_url,
         updated_at = CURRENT_TIMESTAMP
       RETURNING *`,
      [platform.toLowerCase(), latestVersion, minimumVersion, !!forceUpdate, JSON.stringify(releaseNotes || []), downloadUrl]
    );

    res.json({ message: 'App version policy updated successfully.', version: result.rows[0] });
  } catch (error) {
    console.error('Update app version error:', error);
    res.status(500).json({ error: 'Failed to update app version policy.' });
  }
});

export default router;
