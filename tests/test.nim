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
    doAssert numFinds == 14

  block:
    # in range 0.12
    var numFinds = 0
    for other in space.findInRange(a, 0.12):
      inc numFinds
    doAssert numFinds == 121

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
