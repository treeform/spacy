import bumpy, random, spacy, vmath

randomize(2021)

proc randVec2*(r: var Rand): Vec2 =
  let a = r.rand(PI * 2)
  let v = r.rand(1.0)
  vec2(cos(a) * v, sin(a) * v)

template testSpace(name: string, space: untyped) =
  let a = Entry(id: 1, pos: vec2(0, 0))
  space.insert a
  space.insert Entry(id: 2, pos: vec2(0.01, 0))
  space.insert Entry(id: 3, pos: vec2(0.1, 0))
  space.insert Entry(id: 4, pos: vec2(0, 0.2))
  space.finalize()
  doAssert space.len == 4

  block:
    # in range 0.02
    var numFinds = 0
    for other in space.findInRange(a, 0.02):
      doAssert other.id == 2
      inc numFinds
    doAssert numFinds == 1

  block:
    # in range 0.12
    var numFinds = 0
    for other in space.findInRange(a, 0.12):
      doAssert other.id in [2.uint32, 3]
      inc numFinds
    doAssert numFinds == 2

  var rand = initRand(1988)

  space.clear()

  var at: Entry
  for i in 0 .. 1000:
    let e = Entry(id: uint32 i, pos: rand.randVec2())
    space.insert e
    if i == 0:
      at = e
  space.finalize()
  doAssert space.len == 1001

  block:
    # in range 0.02
    var numFinds = 0
    for other in space.findInRange(a, 0.02):
      inc numFinds
    doAssert numFinds == 23

  block:
    # in range 0.12
    var numFinds = 0
    for other in space.findInRange(a, 0.12):
      inc numFinds
    doAssert numFinds == 125

var bs = newBruteSpace()
testSpace("BruteSpace", bs)

var ss = newSortSpace()
testSpace("SortSpace", ss)

var hs = newHashSpace(0.1)
testSpace("HashSpace", hs)

var qs = newQuadSpace(rect(-1.0, -1.0, 2.0, 2.0))
testSpace("QuadSpace", qs)

var ks = newKdSpace(rect(-1.0, -1.0, 2.0, 2.0))
testSpace("KdSpace", ks)

echo "Testing HashSpace queries in negative cells on both axes"
for scale in [1.0, 60_000.0]:
  for direction in [-1, 1]:
    for axis in 0 .. 1:
      var
        query = Entry(id: 1)
        target = Entry(id: 2)
      query.pos[axis] = float32(direction.float * 9 * scale)
      target.pos[axis] = float32(direction.float * 11 * scale)
      let space = newHashSpace(10 * scale)
      space.insert(query)
      space.insert(target)
      space.finalize()
      var found = false
      for entry in space.findInRange(query, 5 * scale):
        doAssert entry.id == target.id
        found = true
      doAssert found, "A nearby target was omitted in a negative cell"

echo "Testing HashSpace against BruteSpace at signed cell boundaries"
block:
  const Count = 289
  let brute = newBruteSpace()
  for x in -8 .. 8:
    for y in -8 .. 8:
      brute.insert Entry(
        id: uint32((x + 8) * 17 + y + 8),
        pos: vec2(x.float * 0.75, y.float * 0.75)
      )
  brute.finalize()
  for resolution in [0.5, 1.0, 2.0, 4.0, 10.0]:
    let space = newHashSpace(resolution)
    for entry in brute.all():
      space.insert(entry)
    space.finalize()
    for coordinate in [
      -10.0, -4.0, -1.0, -0.001, 0.0, 0.001, 1.0, 4.0, 10.0
    ]:
      for axis in 0 .. 1:
        var query = Entry(id: uint32(Count))
        query.pos[axis] = coordinate.float32
        for radius in [0.0, 0.125, 0.5, 1.0, 2.0, 5.0, 10.0]:
          var expected, actual, approximate: array[Count, bool]
          for entry in brute.findInRange(query, radius):
            expected[int(entry.id)] = true
          for entry in space.findInRangeApprox(query, radius):
            approximate[int(entry.id)] = true
          for entry in space.findInRange(query, radius):
            actual[int(entry.id)] = true
          doAssert actual == expected, "HashSpace disagreed with BruteSpace"
          for i in 0 ..< Count:
            doAssert not expected[i] or approximate[i],
              "The approximate query omitted an exact match"
