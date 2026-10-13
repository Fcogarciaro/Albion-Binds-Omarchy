.pragma library

// Small pure helpers shared by the Cultivos and Zona negra views.

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

// "dd/MM/yy" in local time; "-" for an invalid timestamp.
function shortDate(ms) {
  var d = new Date(ms)
  if (isNaN(d.getTime())) return "-"
  return pad2(d.getDate()) + "/" + pad2(d.getMonth() + 1) + "/" + pad2(d.getFullYear() % 100)
}

// Record id: prefix + base-36 clock + a short random part. `now` and `rand`
// are injectable so tests stay deterministic.
function newId(prefix, now, rand) {
  var t = now === undefined ? Date.now() : now
  var r = rand === undefined ? Math.random() : rand
  return prefix + t.toString(36) + Math.floor(r * 1296).toString(36)
}
