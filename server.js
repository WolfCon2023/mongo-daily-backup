const express = require('express')
const { spawn } = require('child_process')
const path = require('path')

const app = express()
const PORT = process.env.PORT || 3000
const BACKUP_SCRIPT = process.env.BACKUP_SCRIPT_PATH || path.join(__dirname, 'backup.sh')

let isRunning = false

app.use(express.json())

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'mongo-daily-backup', timestamp: Date.now() })
})

app.post('/backup-now', async (req, res) => {
  if (isRunning) {
    return res.status(429).json({ ok: false, error: 'backup_in_progress' })
  }

  isRunning = true
  const startedAt = new Date()
  console.log('[mongo-daily-backup] Manual backup requested at', startedAt.toISOString())

  try {
    const child = spawn('sh', [BACKUP_SCRIPT], {
      env: process.env,
      stdio: 'inherit',
    })

    const finishedAt = await new Promise((resolve, reject) => {
      child.on('close', (code) => {
        const done = new Date()
        if (code === 0) {
          console.log('[mongo-daily-backup] backup.sh finished successfully at', done.toISOString())
          resolve(done)
        } else {
          console.error('[mongo-daily-backup] backup.sh exited with code', code)
          reject(new Error(`backup.sh exited with code ${code}`))
        }
      })
      child.on('error', reject)
    })

    res.json({
      ok: true,
      status: 'SUCCESS',
      startedAt: startedAt.toISOString(),
      finishedAt: finishedAt.toISOString(),
    })
  } catch (err) {
    console.error('[mongo-daily-backup] Backup failed:', err)
    res.status(500).json({
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