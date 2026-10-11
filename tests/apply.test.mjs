import { describe, test, beforeEach, afterEach } from "node:test"
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, existsSync, rmSync, chmodSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const APPLY = new URL("../apply.sh", import.meta.url).pathname
const hasLuac = spawnSync("luac", ["-v"], { encoding: "utf8" }).error === undefined
const MARKER = 'pcall(require, "hypr.albion-binds")'
const VALID = "local x = 1\n"

describe("apply.sh", () => {
  let root, hyprDir, calls

  beforeEach(() => {
    root = mkdtempSync(join(tmpdir(), "albion-apply-"))
    hyprDir = join(root, "config", "hypr")
    mkdirSync(hyprDir, { recursive: true })
    writeFileSync(join(hyprDir, "hyprland.lua"), "-- user config\n")
    const bin = join(root, "bin")
    mkdirSync(bin)
    calls = join(root, "calls.log")
    // Fake hyprctl: records its arguments and prints nothing.
    writeFileSync(join(bin, "hyprctl"), `#!/usr/bin/env bash\necho "$*" >> "${calls}"\n`)
    chmodSync(join(bin, "hyprctl"), 0o755)
  })

  afterEach(() => rmSync(root, { recursive: true, force: true }))

  const apply = (content) =>
    spawnSync("bash", [APPLY, content], {
      encoding: "utf8",
      env: {
        ...process.env,
        XDG_CONFIG_HOME: join(root, "config"),
        PATH: `${join(root, "bin")}:${process.env.PATH}`
      }
    })

  const reloads = () =>
    existsSync(calls) ? readFileSync(calls, "utf8").split("\n").filter((l) => l.startsWith("reload")) : []

  test("writes the target, appends the marker once and reloads once", () => {
    const res = apply(VALID)
    assert.equal(res.status, 0, res.stderr)
    assert.equal(readFileSync(join(hyprDir, "albion-binds.lua"), "utf8"), VALID)
    const main = readFileSync(join(hyprDir, "hyprland.lua"), "utf8")
    assert.equal(main.split(MARKER).length - 1, 1)
    assert.equal(reloads().length, 1)
  })

  test("an identical second run does not reload again", () => {
    apply(VALID)
    const res = apply(VALID)
    assert.equal(res.status, 0, res.stderr)
    assert.equal(reloads().length, 1)
    const main = readFileSync(join(hyprDir, "hyprland.lua"), "utf8")
    assert.equal(main.split(MARKER).length - 1, 1)
  })

  test("invalid Lua fails, leaves the target untouched and does not reload", { skip: !hasLuac && "luac not on PATH" }, () => {
    apply(VALID)
    const res = apply("local = =\n")
    assert.equal(res.status, 1)
    assert.notEqual(res.stderr.trim(), "")
    assert.equal(readFileSync(join(hyprDir, "albion-binds.lua"), "utf8"), VALID)
    assert.equal(reloads().length, 1)
    assert.deepEqual(readdirSync(hyprDir).sort(), ["albion-binds.lua", "hyprland.lua"])
  })

  test("invalid Lua never creates a missing target", { skip: !hasLuac && "luac not on PATH" }, () => {
    const res = apply("local = =\n")
    assert.equal(res.status, 1)
    assert.equal(existsSync(join(hyprDir, "albion-binds.lua")), false)
    assert.equal(reloads().length, 0)
  })
})
