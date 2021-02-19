import algorithm, bumpy, math, tables, vmath

type Entry* = object
  id*: uint32
  pos*: Vec2

type BruteSpace* = ref object
  ## Brute space just compares every entry vs every other entry.
  ## Supposed to be good for very small number or large ranges.
  list*: seq[Entry]

proc newBruteSpace*(): BruteSpace =
  result = BruteSpace()
  result.list = newSeq[Entry]()

proc insert*(bs: BruteSpace, e: Entry) {.inline.} =
  bs.list.add e

proc finalize*(bs: BruteSpace) {.inline.} =
  discard

iterator all*(bs: BruteSpace): Entry =
  for e in bs.list:
    yield e

iterator findInRange*(bs: BruteSpace, e: Entry, maxRange: float): Entry =
  let maxRangeSq = maxRange * maxRange
  for thing in bs.list:
    if e.id != thing.id and e.pos.distSq(thing.pos) < maxRangeSq:
      yield thing

iterator findInRangeApprox*(bs: BruteSpace, e: Entry, maxRange: float): Entry =
  for thing in bs.list:
    if e.id != thing.id:
      yield thing

proc clear*(bs: BruteSpace) {.inline.} =
  bs.list.setLen(0)

proc len*(bs: BruteSpace): int {.inline.} =
  bs.list.len

type SortSpace* = ref object
  ## Sort space sorts all entires on one axis X.
  ## Supposed to be good for very small ranges.
  list*: seq[Entry]

proc newSortSpace*(): SortSpace =
  result = SortSpace()
  result.list = newSeq[Entry]()

proc insert*(ss: SortSpace, e: Entry) {.inline.} =
  ss.list.add e

proc sortSpaceCmp(a, b: Entry): int =
  cmp(a.pos.x, b.pos.x)

proc finalize*(ss: SortSpace) {.inline.} =
  ss.list.sort(sortSpaceCmp)

iterator all*(ss: SortSpace): Entry =
  for e in ss.list:
    yield e

iterator findInRange*(ss: SortSpace, e: Entry, maxRange: float): Entry =
  let
    maxRangeSq = maxRange * maxRange
    l = ss.list

  # find index of entry
  let index = ss.list.lowerBound(e, sortSpaceCmp)

  # scan to the right
  var right = index
  while right < l.len:
    let thing = l[right]
    if thing.pos.x - e.pos.x > maxRange:
      break
    if thing.id != e.id and thing.pos.distSq(e.pos) < maxRangeSq:
      yield thing
    inc right

  # scan to the left
  var left = index - 1
  while left >= 0:
    let thing = l[left]
    if e.pos.x - thing.pos.x > maxRange:
      break
    if thing.pos.distSq(e.pos) < maxRangeSq:
      yield thing
    dec left

iterator findInRangeApprox*(ss: SortSpace, e: Entry, maxRange: float): Entry =
  let
    l = ss.list

  # find index of entry
  let index = ss.list.lowerBound(e, sortSpaceCmp)

  # scan to the right
  var right = index
  while right < l.len:
    let thing = l[right]
    if thing.pos.x - e.pos.x > maxRange:
      break
    if thing.id != e.id:
      yield thing
    inc right

  # scan to the left
  var left = index - 1
  while left >= 0:
    let thing = l[left]
    if e.pos.x - thing.pos.x > maxRange:
      break
    yield thing
    dec left

proc clear*(ss: SortSpace) {.inline.} =
  ss.list.setLen(0)

proc len*(ss: SortSpace): int {.inline.} =
  ss.list.len

type HashSpace* = ref object
  ## Divides space into little tiles that objects are hashed too.
  ## Supposed to be good for very uniform filled space.
  hash*: TableRef[(int32, int32), seq[Entry]]
  resolution*: float

proc newHashSpace*(resolution: float): HashSpace =
  result = HashSpace()
  result.hash = newTable[(int32, int32), seq[Entry]]()
  result.resolution = resolution

proc hashSpaceKey(hs: HashSpace, e: Entry): (int32, int32) =
  (int32(floor(e.pos.x / hs.resolution)), int32(floor(e.pos.y / hs.resolution)))

proc insert*(hs: HashSpace, e: Entry) =
  let key = hs.hashSpaceKey(e)
  if key in hs.hash:
    hs.hash[key].add(e)
  else:
    hs.hash[key] = @[e]

iterator all*(hs: HashSpace): Entry =
  for list in hs.hash.values:
    for e in list:
      yield e

proc clamp(value, min, max: float): float =
  if value < min:
    return min
  if value > max:
    return max
  return value

proc overlapRectCircle(point: Vec2, radius, x, y, w, h: float): bool =
  let
    dx = point.x - clamp(point.x, x, x + w)
    dy = point.y - clamp(point.y, y, y + h)
  return (dx * dx + dy * dy) <= (radius * radius)

iterator findInRangeApprox*(hs: HashSpace, e: Entry, maxRange: float): Entry =
  let
    d = int(maxRange / hs.resolution) + 1
    px = int(e.pos.x / hs.resolution)
    py = int(e.pos.y / hs.resolution)

  for x in -d .. d:
    for y in -d .. d:
      let
        rx = px + x
        ry = py + y
      if overlapRectCircle(e.pos, maxRange, float(rx) * hs.resolution, float(
          ry) * hs.resolution, hs.resolution, hs.resolution):
        let posKey = (int32 rx, int32 ry)
        if posKey in hs.hash:
          for thing in hs.hash[posKey]:
            if thing.id != e.id:
              yield thing

iterator findInRange*(hs: HashSpace, e: Entry, maxRange: float): Entry =
  let
    d = int(maxRange / hs.resolution) + 1
    px = int(e.pos.x / hs.resolution)
    py = int(e.pos.y / hs.resolution)
    maxRangeSq = maxRange * maxRange

  for x in -d .. d:
    for y in -d .. d:
      let
        rx = px + x
        ry = py + y
      if overlapRectCircle(e.pos, maxRange, float(rx) * hs.resolution, float(
          ry) * hs.resolution, hs.resolution, hs.resolution):
        let posKey = (int32 rx, int32 ry)
        if posKey in hs.hash:
          for thing in hs.hash[posKey]:
            if thing.id != e.id and thing.pos.distSq(e.pos) < maxRangeSq:
              yield thing

proc clear*(hs: HashSpace) {.inline.} =
  hs.hash.clear()

proc finalize*(hs: HashSpace) {.inline.} =
  discard

proc len*(hs: HashSpace): int {.inline.} =
  for list in hs.hash.values:
    result += list.len

type
  QuadSpace* = ref object
    ## QuadTree, divide each node down if there is many elements.
    ## Supposed to be for large amount of entries.
    root*: QuadNode
    maxThings*: int # when should node divide
    maxLevels*: int # how many levels should node build

  QuadNode* = ref object
    things*: seq[Entry]
    nodes*: seq[QuadNode]
    bounds*: Rect
    level*: int

proc newQuadNode(bounds: Rect, level: int): QuadNode =
  result = QuadNode()
  result.bounds = bounds
  result.level = level

proc newQuadSpace*(bounds: Rect, maxThings = 10, maxLevels = 10): QuadSpace =
  result = QuadSpace()
  result.root = newQuadNode(bounds, 0)
  result.maxThings = maxThings
  result.maxLevels = maxLevels

proc insert*(qs: QuadSpace, e: Entry)
proc insert*(qs: QuadSpace, qn: var QuadNode, e: Entry)

proc whichQuadrant(qs: QuadNode, e: Entry): int =
  let
    xMid = qs.bounds.x + qs.bounds.w/2
    yMid = qs.bounds.y + qs.bounds.h/2
  if e.pos.x < xMid:
    if e.pos.y < yMid:
      return 0
    else:
      return 1
  else:
    if e.pos.y < yMid:
      return 2
    else:
      return 3

proc split(qs: QuadSpace, qn: var QuadNode) =
  let
    nextLevel = qn.level + 1
    x = qn.bounds.x
    y = qn.bounds.y
    w = qn.bounds.w/2
    h = qn.bounds.h/2
  qn.nodes = @[
    newQuadNode(Rect(x: x, y: y, w: w, h: h), nextLevel),
    newQuadNode(Rect(x: x, y: y+h, w: w, h: h), nextLevel),
    newQuadNode(Rect(x: x+w, y: y, w: w, h: h), nextLevel),
    newQuadNode(Rect(x: x+w, y: y+h, w: w, h: h), nextLevel)
  ]
  for e in qn.things:
    let index = qn.whichQuadrant(e)
    qs.insert(qn.nodes[index], e)
  qn.things.setLen(0)

proc insert*(qs: QuadSpace, qn: var QuadNode, e: Entry) =
  if qn.nodes.len != 0:
    let index = qn.whichQuadrant(e)
    qs.insert(qn.nodes[index], e)
  else:
    qn.things.add e
    if qn.things.len > qs.maxThings and qn.level < qs.maxLevels:
      qs.split(qn)

proc insert*(qs: QuadSpace, e: Entry) =
  qs.insert(qs.root, e)

proc overlaps(qs: QuadNode, e: Entry, maxRange: float): bool =
  return overlapRectCircle(e.pos, maxRange, qs.bounds.x, qs.bounds.y,
      qs.bounds.w, qs.bounds.h)

iterator findInRangeApprox*(qs: QuadSpace, e: Entry, maxRange: float): Entry =
  var nodes = @[qs.root]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        if node.overlaps(e, maxRange):
          nodes.add(node)
    else:
      for e in qs.things:
        yield e

iterator findInRange*(qs: QuadSpace, e: Entry, maxRange: float): Entry =
  let maxRangeSq = maxRange * maxRange
  var nodes = @[qs.root]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        if node.overlaps(e, maxRange):
          nodes.add(node)
    else:
      for thing in qs.things:
        if thing.id != e.id and thing.pos.distSq(e.pos) < maxRangeSq:
          yield thing

iterator all*(qs: QuadSpace): Entry =
  var nodes = @[qs.root]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        nodes.add(node)
    else:
      for e in qs.things:
        yield e

proc clear*(qs: QuadSpace) {.inline.} =
  qs.root.nodes.setLen(0)
  qs.root.things.setLen(0)

proc finalize*(qs: QuadSpace) {.inline.} =
  discard

proc len*(qs: QuadSpace): int {.inline.} =
  var nodes = @[qs.root]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        nodes.add(node)
    else:
      result += qs.things.len

type
  KdSpace* = ref object
    ## KD-Tree, each cell is divided vertically or horizontally.
    ## Supposed to be good for large amount of entries.
    root*: KdNode
    maxThings*: int # When should node divide?

  KdNode* = ref object
    things*: seq[Entry]
    nodes*: seq[KdNode]
    bounds*: Rect
    level*: int

proc newKdNode*(bounds: Rect, level: int): KdNode =
  result = KdNode()
  result.bounds = bounds
  result.level = level

proc newKdSpace*(bounds: Rect, maxThings = 10, maxLevels = 10): KdSpace =
  result = KdSpace()
  result.root = newKdNode(bounds, 0)
  result.maxThings = maxThings

proc insert*(ks: KdSpace, e: Entry) {.inline.} =
  ks.root.things.add e

proc finalize(ks: KdSpace, kn: KdNode) =
  if kn.things.len > ks.maxThings:
    var axis =
      if kn.bounds.w > kn.bounds.h: 0
      else: 1
    kn.things.sort proc(a, b: Entry): int = cmp(a.pos[axis], b.pos[axis])
    let
      b = kn.bounds
      arr1 = kn.things[0 ..< kn.things.len div 2]
      arr2 = kn.things[kn.things.len div 2 .. ^1]
      mid = arr1[^1].pos[axis]
    var
      node1: KdNode
      node2: KdNode
    if axis == 0:
      let midW = mid - b.x
      node1 = newKdNode(rect(b.x, b.y, midW, b.h), kn.level + 1)
      node2 = newKdNode(rect(mid, b.y, b.w - midW, b.h), kn.level + 1)
    else:
      let midH = mid - b.y
      node1 = newKdNode(rect(b.x, b.y, b.w, midH), kn.level + 1)
      node2 = newKdNode(rect(b.x, mid, b.w, b.h - midH), kn.level + 1)
    node1.things = arr1
    node2.things = arr2
    ks.finalize(node1)
    ks.finalize(node2)
    kn.things.setLen(0)
    kn.nodes = @[node1, node2]

proc finalize*(ks: KdSpace) =
  ks.finalize(ks.root)

proc overlaps(kn: KdNode, e: Entry, maxRange: float): bool =
  return overlapRectCircle(e.pos, maxRange, kn.bounds.x, kn.bounds.y,
      kn.bounds.w, kn.bounds.h)

iterator findInRangeApprox*(ks: KdSpace, e: Entry, maxRange: float): Entry =
  var nodes = @[ks.root]
  while nodes.len > 0:
    var kn = nodes.pop()
    if kn.nodes.len == 2:
      for node in kn.nodes:
        if node.overlaps(e, maxRange):
          nodes.add(node)
    else:
      for e in kn.things:
        yield e

iterator findInRange*(ks: KdSpace, e: Entry, maxRange: float): Entry =
  let maxRangeSq = maxRange * maxRange
  var nodes = @[ks.root]
  while nodes.len > 0:
    var kn = nodes.pop()
    if kn.nodes.len == 2:
      for node in kn.nodes:
        if node.overlaps(e, maxRange):
          nodes.add(node)
    else:
      for thing in kn.things:
        if thing.id != e.id and thing.pos.distSq(e.pos) < maxRangeSq:
          yield thing

iterator all*(ks: KdSpace): Entry =
  var nodes = @[ks.root]
  while nodes.len > 0:
    var kn = nodes.pop()
    if kn.nodes.len == 2:
      for node in kn.nodes:
        nodes.add(node)
    else:
      for e in kn.things:
        yield e

proc clear*(ks: KdSpace) {.inline.} =
  ks.root.things.setLen(0)
  ks.root.nodes.setLen(0)

proc len*(ks: KdSpace): int =
  var nodes = @[ks.root]
  while nodes.len > 0:
    var kn = nodes.pop()
    if kn.nodes.len == 2:
      for node in kn.nodes:
        nodes.add(node)
    else:
      result += kn.things.len
