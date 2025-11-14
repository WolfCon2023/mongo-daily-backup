// server.js
const express = require('express')
const { spawn } = require('child_process')
const path = require('path')

const app = express()
const PORT = process.env.PORT || 3000

// Path to your backup script; adjust if needed
// If backup.sh is in the same folder as server.js:
const BACKUP_SCRIPT = process.env.BACKUP_SCRIPT_PATH || path.join(__dirname, 'backup.sh')

// Prevent concurrent runs
let isRunning = false

app.use(express.json())

// Simple health endpoint for Railway
app.get('/health', (req, res) => {
  return res.json({ ok: true, service: 'mongo-daily-backup', timestamp: Date.now() })
})

// POST /backup-now – webhook target for DB_BACKUP_WEBHOOK_URL
app.post('/backup-now', async (req, res) => {
  if (isRunning) {
    return res.status(429).json({ ok: false, error: 'backup_in_progress' })
  }

  isRunning = true
  const startedAt = new Date()

  console.log('[mongo-daily-backup] Manual backup requested at', startedAt.toISOString())

  try {
    // Run the shell script
    const child = spawn('sh', [BACKUP_SCRIPT], {
      env: process.env,        // keep MONGO_URI, ALERT_*, SMTP_* etc.
      stdio: 'inherit',        // log to container stdout/stderr
    })

    child.on('error', (err) => {
      console.error('[mongo-daily-backup] Failed to start backup.sh:', err)
    })

    child.on('close', (code) => {
      const finishedAt = new Date()
      const status = code === 0 ? 'SUCCESS' : 'FAILED'

      console.log(
        `[mongo-daily-backup] backup.sh finished with code ${code} at ${finishedAt.toISOString()} (status=${status})`
      )
    })

    // Wait for the script to finish before responding
    const finishedAt = await new Promise((resolve, reject) => {
      child.on('close', (code) => {
        const done = new Date()
        if (code === 0) {
          resolve(done)
        } else {
          reject(new Error(`backup.sh exited with code ${code}`))
        }
      })
      child.on('error', reject)
    })

    return res.json({
      ok: true,
      startedAt: startedAt.toISOString(),
      finishedAt: finishedAt.toISOString(),
      status: 'SUCCESS',
    })
  } catch (err) {
    console.error('[mongo-daily-backup] Backup failed:', err)
    return res.status(500).json({
      ok: false,
      status: 'FAILED',
      error: err && err.message ? err.message : String(err),
    })
  } finally {
    isRunning = false
  }
})

app.listen(PORT, () => {
  console.log(`[mongo-daily-backup] HTTP server listening on port ${PORT}`)
})