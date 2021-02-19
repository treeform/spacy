import benchy, bumpy, random, spacy, vmath

proc makeEntries(num: int): seq[Entry] =
  var rand = initRand(1988)
  for i in 0 ..< num:
    result.add Entry(id: uint32 i, pos: rand.randVec2())

template testSetup(num: int, name: string, newSpace: untyped) =
  var entries = makeEntries(num)
  timeIt $num & " " & name & " setup", 100:
    var space = newSpace
    for e in entries:
      space.insert(e)
    space.finalize()
    keep(space)

for num in [10, 100, 1000]:
  testSetup(num, "BruteSpace", newBruteSpace())
  testSetup(num, "SortSpace", newSortSpace())
  testSetup(num, "HashSpace", newHashSpace(0.25))
  testSetup(num, "QuadSpace", newQuadSpace(rect(-1.0, -1.0, 1.0, 1.0)))
  testSetup(num, "KdSpace", newKdSpace(rect(-1.0, -1.0, 1.0, 1.0)))

template testScan(num: int, dist: float32, name: string, newSpace: untyped) =
  var entries = makeEntries(num)

  timeIt name, 100:
    var space = newSpace
    for e in entries:
      space.insert(e)
    space.finalize()

    for me in entries:
      for other in space.findInRange(me, dist):
        keep(other)

for num in [10, 100, 1000]:
  for dist in [0.001, 0.1, 1.00]:
    echo num, " entries at ", dist, " distance:"
    testScan(num, dist, "BruteSpace", newBruteSpace())
    testScan(num, dist, "SortSpace", newSortSpace())
    testScan(num, dist, "HashSpace", newHashSpace(dist))
    testScan(num, dist, "QuadSpace", newQuadSpace(rect(-1.0, -1.0, 1.0, 1.0)))
    testScan(num, dist, "KdSpace", newKdSpace(rect(-1.0, -1.0, 1.0, 1.0)))

template benchApprox(num: int, dist: float32, name: string, newSpace: untyped) =
  var entries = makeEntries(num)
  var space = newSpace
  for e in entries:
    space.insert(e)
  space.finalize()

  timeIt name & " exact", 100:
    for me in entries:
      for other in space.findInRange(me, dist):
        keep(other)

  timeIt name & " approx", 100:
    for me in entries:
      for other in space.findInRangeApprox(me, dist):
        keep(other)

block:
  let num = 1000
  let dist = 0.1
  echo num, " entries at ", dist, " distance:"
  benchApprox(num, dist, "BruteSpace", newBruteSpace())
  benchApprox(num, dist, "SortSpace", newSortSpace())
  benchApprox(num, dist, "HashSpace", newHashSpace(dist))
  benchApprox(num, dist, "QuadSpace", newQuadSpace(rect(-1.0, -1.0, 1.0, 1.0)))
  benchApprox(num, dist, "KdSpace", newKdSpace(rect(-1.0, -1.0, 1.0, 1.0)))
