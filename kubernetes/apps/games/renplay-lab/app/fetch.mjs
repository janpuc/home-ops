// The lab's fetcher (renplay-org/lab): downloads an itch.io upload straight into the lab Renplay's
// archives folder on the NAS, so a big game never passes through a laptop. It fetches only itch.io
// uploads, by their id, with the lab's API key: no other address can be given to it.
//
//   POST /fetch {"upload": 123, "name": "Game-1.0-pc.zip"}   starts a download, answers {"id"}
//   GET  /fetch/<id>                                          its state, bytes, size and sha256
//   GET  /health
import { createHash, randomUUID } from 'node:crypto'
import { createWriteStream } from 'node:fs'
import { access, rename, unlink } from 'node:fs/promises'
import { createServer } from 'node:http'
import { join } from 'node:path'
import { Readable } from 'node:stream'
import { pipeline } from 'node:stream/promises'

const DIR = process.env.ARCHIVES_DIR ?? '/archives'
const KEY = process.env.ITCH_API_KEY
const PORT = Number(process.env.PORT ?? 8080)
const NAME = /^[A-Za-z0-9][A-Za-z0-9 ._()+-]{0,200}\.(zip|7z|rar)$/

const jobs = new Map()
let running = null

async function download(job) {
  const res = await fetch(`https://api.itch.io/uploads/${job.upload}/download`, {
    headers: { authorization: `Bearer ${KEY}` },
    redirect: 'manual',
    signal: AbortSignal.timeout(30_000),
  })
  // The API answers with a redirect to a signed address on itch.io's CDN, which needs no key.
  const location = res.headers.get('location')
  if (!location) throw new Error(`itch.io answered ${res.status} for upload ${job.upload}`)
  const file = await fetch(location, { signal: AbortSignal.timeout(6 * 60 * 60 * 1000) })
  if (!file.ok || !file.body) throw new Error(`the file answered ${file.status}`)
  job.total = Number(file.headers.get('content-length')) || null
  const hash = createHash('sha256')
  const part = join(DIR, `.${job.name}.part`)
  const meter = new TransformStream({
    transform(chunk, controller) {
      hash.update(chunk)
      job.bytes += chunk.length
      controller.enqueue(chunk)
    },
  })
  try {
    await pipeline(Readable.fromWeb(file.body.pipeThrough(meter)), createWriteStream(part, { flags: 'wx' }))
    await rename(part, join(DIR, job.name))
  } catch (error) {
    await unlink(part).catch(() => {})
    throw error
  }
  job.sha256 = hash.digest('hex')
}

async function start(job) {
  running = job
  try {
    await download(job)
    job.state = 'done'
  } catch (error) {
    job.state = 'failed'
    job.error = error.message
  } finally {
    job.finishedAt = new Date().toISOString()
    running = null
    console.log(JSON.stringify({ upload: job.upload, name: job.name, state: job.state, bytes: job.bytes, error: job.error }))
  }
}

const exists = (path) => access(path).then(() => true, () => false)

const reply = (res, status, body) => {
  res.writeHead(status, { 'content-type': 'application/json' })
  res.end(JSON.stringify(body))
}

createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/health') return reply(res, 200, { ok: true, busy: !!running })
    const status = req.url?.match(/^\/fetch\/([0-9a-f-]{36})$/)
    if (req.method === 'GET' && status) {
      const job = jobs.get(status[1])
      return job ? reply(res, 200, job) : reply(res, 404, { error: 'No such download' })
    }
    if (req.method === 'POST' && req.url === '/fetch') {
      let body = ''
      for await (const chunk of req) {
        body += chunk
        if (body.length > 4096) return reply(res, 413, { error: 'Too large' })
      }
      const { upload, name } = JSON.parse(body || '{}')
      if (!Number.isSafeInteger(upload) || upload <= 0) return reply(res, 400, { error: 'upload must be an itch.io upload id' })
      if (typeof name !== 'string' || !NAME.test(name)) return reply(res, 400, { error: 'name must be a plain archive file name' })
      if (running) return reply(res, 409, { error: `Busy with ${running.name}`, id: running.id })
      if (await exists(join(DIR, name))) return reply(res, 409, { error: `${name} is in the archives folder already` })
      const job = { id: randomUUID(), upload, name, state: 'running', bytes: 0, total: null, sha256: null, startedAt: new Date().toISOString() }
      jobs.set(job.id, job)
      void start(job)
      return reply(res, 202, { id: job.id })
    }
    reply(res, 404, { error: 'Not found' })
  } catch (error) {
    reply(res, 400, { error: error.message })
  }
}).listen(PORT, () => console.log(`renplay-lab-fetch on ${PORT}, into ${DIR}`))

if (!KEY) console.error('ITCH_API_KEY is not set')
