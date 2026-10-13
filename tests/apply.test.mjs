import { describe, test, beforeEach, afterEach } from "node:test"
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdtempSync, mkdirSync, writeFileSync, symlinkSync, lstatSync, readFileSync, readdirSync, existsSync, rmSync, chmodSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const APPLY = new URL("../binds/apply.sh", import.meta.url).pathname
const hasLuac = spawnSync("luac", ["-v"], { encoding: "utf8" }).error === undefined
const MARKER = 'pcall(require, "hypr.albion-companion")'
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
    assert.equal(readFileSync(join(hyprDir, "albion-companion.lua"), "utf8"), VALID)
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
    assert.equal(readFileSync(join(hyprDir, "albion-companion.lua"), "utf8"), VALID)
    assert.equal(reloads().length, 1)
    assert.deepEqual(readdirSync(hyprDir).sort(), ["albion-companion.lua", "hyprland.lua"])
  })

  test("invalid Lua never creates a missing target", { skip: !hasLuac && "luac not on PATH" }, () => {
    const res = apply("local = =\n")
    assert.equal(res.status, 1)
    assert.equal(existsSync(join(hyprDir, "albion-companion.lua")), false)
    assert.equal(reloads().length, 0)
  })

  const LEGACY_LINE = 'pcall(require, "hypr.albion-binds")'
  const LEGACY_COMMENT = "-- Albion Binds (plugin fcogarcia.albion-binds): atajos solo para Albion Online."

  test("legacy loader line, comment and file are removed; everything else is preserved", () => {
    const keep = '-- my albion notes\nhl.bind("SUPER+A", albion_thing)  -- albion\nlocal albion_binds_unrelated = 1\n'
    writeFileSync(join(hyprDir, "hyprland.lua"), `-- user config\n${keep}\n${LEGACY_COMMENT}\n${LEGACY_LINE}\n`)
    writeFileSync(join(hyprDir, "albion-binds.lua"), "old\n")
    const res = apply(VALID)
    assert.equal(res.status, 0, res.stderr)
    const main = readFileSync(join(hyprDir, "hyprland.lua"), "utf8")
    assert.equal(main.includes(LEGACY_LINE), false)
    assert.equal(main.includes("Albion Binds (plugin"), false)
    assert.ok(main.includes(`-- user config\n${keep}`))
    assert.equal(main.split(MARKER).length - 1, 1)
    assert.match(main, /-- Albion Companion \(plugin fcogarcia\.albion-companion\)/)
    assert.equal(existsSync(join(hyprDir, "albion-binds.lua")), false)
    assert.equal(readFileSync(join(hyprDir, "albion-companion.lua"), "utf8"), VALID)
    assert.equal(reloads().length, 1)
  })

  test("legacy cleanup alone (target already current) still reloads once", () => {
    apply(VALID)
    const main = join(hyprDir, "hyprland.lua")
    writeFileSync(main, readFileSync(main, "utf8") + `\n${LEGACY_LINE}\n`)
    const res = apply(VALID)
    assert.equal(res.status, 0, res.stderr)
    assert.equal(readFileSync(main, "utf8").includes(LEGACY_LINE), false)
    assert.equal(reloads().length, 2)
  })

  test("without legacy leftovers the user's config is only appended to", () => {
    const original = "-- user config\n-- albion is fun\n"
    writeFileSync(join(hyprDir, "hyprland.lua"), original)
    apply(VALID)
    const main = readFileSync(join(hyprDir, "hyprland.lua"), "utf8")
    assert.ok(main.startsWith(original))
    assert.equal(existsSync(join(hyprDir, "albion-binds.lua")), false)
  })

  test("a symlinked hyprland.lua stays a symlink and the real file is edited", () => {
    const dots = join(root, "dotfiles")
    mkdirSync(dots)
    writeFileSync(join(dots, "hyprland.lua"), "-- dotfiles config\n")
    rmSync(join(hyprDir, "hyprland.lua"))
    symlinkSync(join(dots, "hyprland.lua"), join(hyprDir, "hyprland.lua"))
    const res = apply(VALID)
    assert.equal(res.status, 0, res.stderr)
    assert.equal(lstatSync(join(hyprDir, "hyprland.lua")).isSymbolicLink(), true)
    assert.ok(readFileSync(join(dots, "hyprland.lua"), "utf8").includes(MARKER))
    assert.deepEqual(readdirSync(dots), ["hyprland.lua"])
  })

  test("a symlinked legacy cleanup keeps the symlink too", () => {
    const dots = join(root, "dotfiles")
    mkdirSync(dots)
    writeFileSync(join(dots, "hyprland.lua"), `-- mine\n${MARKER.replace("companion", "binds")}\n`)
    rmSync(join(hyprDir, "hyprland.lua"))
    symlinkSync(join(dots, "hyprland.lua"), join(hyprDir, "hyprland.lua"))
    const res = apply(VALID)
    assert.equal(res.status, 0, res.stderr)
    assert.equal(lstatSync(join(hyprDir, "hyprland.lua")).isSymbolicLink(), true)
    assert.ok(!readFileSync(join(dots, "hyprland.lua"), "utf8").includes("albion-binds"))
  })

  test("a symlinked target keeps its link", () => {
    const dots = join(root, "dotfiles")
    mkdirSync(dots)
    writeFileSync(join(dots, "albion-companion.lua"), "-- old\n")
    symlinkSync(join(dots, "albion-companion.lua"), join(hyprDir, "albion-companion.lua"))
    const res = apply(VALID)
    assert.equal(res.status, 0, res.stderr)
    assert.equal(lstatSync(join(hyprDir, "albion-companion.lua")).isSymbolicLink(), true)
    assert.equal(readFileSync(join(dots, "albion-companion.lua"), "utf8"), VALID)
  })

  test("a failing mv leaves no temp file behind", () => {
    writeFileSync(join(root, "bin", "mv"), "#!/usr/bin/env bash\nexit 1\n")
    chmodSync(join(root, "bin", "mv"), 0o755)
    const res = apply(VALID)
    assert.notEqual(res.status, 0)
    assert.deepEqual(readdirSync(hyprDir).sort(), ["hyprland.lua"])
  })
})
