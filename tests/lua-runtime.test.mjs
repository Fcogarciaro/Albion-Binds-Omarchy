import { describe, test, before, after } from "node:test"
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdtempSync, writeFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { loadBinds } from "./helpers/load-model.mjs"

const Model = loadBinds()
const hasBin = (name) => spawnSync(name, ["-v"], { encoding: "utf8" }).error === undefined
const hasLua = hasBin("lua")
const hasLuac = hasBin("luac")

// Mock of the Hyprland Lua API. Timers are queued and flushed by the scenario.
const PRELUDE = `
local state = { window = nil, handlers = {}, timers = {}, binds = {}, events = {}, log = {}, unbind_calls = 0 }
_G.state = state

hl = {}
hl.dsp = { send_key_state = function(t) return t end }

function hl.bind(keys, fn, opts)
  local handle = { keys = keys, fn = fn, opts = opts, active = true }
  function handle:unbind()
    self.active = false
    table.insert(state.log, "handle_unbind:" .. self.keys)
  end
  table.insert(state.binds, handle)
  table.insert(state.log, "bind:" .. keys)
  return handle
end

function hl.unbind(keys)
  state.unbind_calls = state.unbind_calls + 1
  table.insert(state.log, "hl_unbind:" .. tostring(keys))
end

function hl.on(event, cb)
  state.handlers[event] = cb
  return { remove = function() state.handlers[event] = nil end }
end

function hl.timer(fn, opts)
  table.insert(state.timers, fn)
  return { opts = opts }
end

function hl.dispatch(ev)
  table.insert(state.events, ev.key .. "[" .. ev.mods .. "]" .. ev.state)
end

function hl.get_active_window() return state.window end

function set_window(w)
  state.window = w
  state.handlers["window.active"](w)
end

function flush_timers()
  while #state.timers > 0 do
    local fn = table.remove(state.timers, 1)
    fn()
  end
end

function flush_one_timer()
  local fn = table.remove(state.timers, 1)
  if fn then fn() end
end

function active_binds()
  local n = 0
  for _, h in ipairs(state.binds) do if h.active then n = n + 1 end end
  return n
end

function press(index)
  local active = {}
  for _, h in ipairs(state.binds) do if h.active then table.insert(active, h) end end
  active[index or 1].fn()
end

function events() return table.concat(state.events, ";") end
function out(name, value) print(name .. "=" .. tostring(value)) end
`

function runScenario(lua, scenario) {
  const dir = mkdtempSync(join(tmpdir(), "albion-lua-"))
  try {
    writeFileSync(join(dir, "prelude.lua"), PRELUDE)
    writeFileSync(join(dir, "generated.lua"), lua)
    writeFileSync(join(dir, "scenario.lua"), `dofile("prelude.lua")\ndofile("generated.lua")\n${scenario}\n`)
    const res = spawnSync("lua", ["scenario.lua"], { cwd: dir, encoding: "utf8" })
    assert.equal(res.status, 0, `lua failed: ${res.stderr}`)
    const values = {}
    for (const line of res.stdout.split("\n")) {
      const i = line.indexOf("=")
      if (i > 0) values[line.slice(0, i)] = line.slice(i + 1)
    }
    return values
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

const SHIFT_N = [{ trigger: "mouse:275", combo: "SHIFT+N", enabled: true }]
const generated = Model.generateLua(SHIFT_N, true)

describe("generated Lua", { skip: !hasLua && "lua not on PATH" }, () => {
  test("luac -p accepts the generated file", { skip: !hasLuac && "luac not on PATH" }, () => {
    const dir = mkdtempSync(join(tmpdir(), "albion-luac-"))
    try {
      for (const [name, binds, on] of [["a", SHIFT_N, true], ["b", [], true], ["c", SHIFT_N, false]]) {
        const file = join(dir, `${name}.lua`)
        writeFileSync(file, Model.generateLua(binds, on))
        const res = spawnSync("luac", ["-p", file], { encoding: "utf8" })
        assert.equal(res.status, 0, res.stderr)
      }
    } finally {
      rmSync(dir, { recursive: true, force: true })
    }
  })

  test("no window focused: nothing is bound", () => {
    const r = runScenario(generated, `out("active", active_binds())`)
    assert.equal(r.active, "0")
  })

  test("focusing Albion registers the binds with a description", () => {
    const r = runScenario(generated, `
      set_window({ class = "Albion-Online" })
      out("active", active_binds())
      out("keys", state.binds[1].keys)
      out("desc", state.binds[1].opts.description)
    `)
    assert.equal(r.active, "1")
    assert.equal(r.keys, "mouse:275")
    assert.equal(r.desc, "Albion: SHIFT+N")
  })

  test("focusing another window does not register binds", () => {
    const r = runScenario(generated, `
      set_window({ class = "firefox" })
      out("active", active_binds())
    `)
    assert.equal(r.active, "0")
  })

  test("a trigger sends the modifier sequence in order", () => {
    const r = runScenario(generated, `
      set_window({ class = "Albion-Online" })
      press()
      flush_timers()
      out("events", events())
    `)
    assert.equal(r.events, "Shift_L[]down;N[SHIFT]down;N[SHIFT]up;Shift_L[]up")
  })

  test("master switch off generates a file that never binds", () => {
    const off = Model.generateLua(SHIFT_N, false)
    const r = runScenario(off, `
      out("has_handler", state.handlers["window.active"] ~= nil)
      out("active", active_binds())
    `)
    assert.equal(r.has_handler, "false")
    assert.equal(r.active, "0")
  })
  test("leaving Albion unbinds through handles and never calls hl.unbind", () => {
    const r = runScenario(generated, `
      set_window({ class = "Albion-Online" })
      set_window({ class = "firefox" })
      out("active", active_binds())
      out("unbind_calls", state.unbind_calls)
      out("log", table.concat(state.log, ","))
    `)
    assert.equal(r.active, "0")
    assert.equal(r.unbind_calls, "0")
    assert.equal(r.log, "bind:mouse:275,handle_unbind:mouse:275")
  })

  test("re-entering Albion binds again with a fresh handle", () => {
    const r = runScenario(generated, `
      set_window({ class = "Albion-Online" })
      set_window({ class = "firefox" })
      set_window({ class = "Albion-Online" })
      out("active", active_binds())
      out("total", #state.binds)
    `)
    assert.equal(r.active, "1")
    assert.equal(r.total, "2")
  })

  test("initial_class is matched when class differs", () => {
    const r = runScenario(generated, `
      set_window({ class = "steam_app_123", initial_class = "Albion-Online" })
      out("active", active_binds())
    `)
    assert.equal(r.active, "1")
  })

  test("focus change mid-sequence releases everything and aborts the sequence", () => {
    const r = runScenario(generated, `
      set_window({ class = "Albion-Online" })
      press()
      flush_one_timer()
      local before = #state.events
      set_window({ class = "firefox" })
      local after_release = #state.events
      flush_timers()
      out("events", events())
      out("late_events", #state.events - after_release)
      out("before", before)
    `)
    assert.equal(r.late_events, "0")
    const balance = {}
    for (const ev of r.events.split(";")) {
      const [, key, state] = ev.match(/^(\w+)\[.*\](down|up)$/)
      balance[key] = (balance[key] ?? 0) + (state === "down" ? 1 : -1)
    }
    assert.deepEqual(balance, { Shift_L: 0, N: 0 })
    assert.match(r.events, /Shift_L\[\]up$/)
  })

  test("modifiers are released in reverse order on focus loss", () => {
    const multi = Model.generateLua([{ trigger: "F5", combo: "CTRL+ALT+M", enabled: true }], true)
    const r = runScenario(multi, `
      set_window({ class = "Albion-Online" })
      press()
      flush_one_timer()
      flush_one_timer()
      set_window({ class = "firefox" })
      flush_timers()
      out("events", events())
    `)
    assert.equal(r.events, "Control_L[]down;Alt_L[CTRL]down;M[CTRL ALT]down;M[CTRL ALT]up;Alt_L[CTRL]up;Control_L[]up")
  })

  test("a second trigger while a sequence is in flight is ignored", () => {
    const r = runScenario(generated, `
      set_window({ class = "Albion-Online" })
      press()
      press()
      flush_timers()
      out("events", events())
      press()
      flush_timers()
      out("count", #state.events)
    `)
    assert.equal(r.events, "Shift_L[]down;N[SHIFT]down;N[SHIFT]up;Shift_L[]up")
    assert.equal(r.count, "8")
  })

  test("generated comments are in English", () => {
    assert.match(generated, /^-- Generated by the Albion Binds plugin/)
    assert.doesNotMatch(generated, /Generado|Albion \(XWayland\) ignora/)
  })
})
