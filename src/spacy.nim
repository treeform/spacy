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

const maxThings = 10
const maxLevels = 7

type QuadSpace* = ref object
  ## QuadTree, divide each node down if there is many elements.
  ## Supposed to be for large amount of entries.
  things*: seq[Entry]
  nodes*: seq[QuadSpace]
  bounds*: Rect
  level*: int

proc newQuadSpace*(bounds: Rect, level: int = 0): QuadSpace =
  result = QuadSpace()
  result.bounds = bounds
  result.level = level

proc insert*(qs: QuadSpace, e: Entry)

proc whichQuadrant(qs: QuadSpace, e: Entry): int =
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

proc split(qs: QuadSpace) =
  let
    nextLevel = qs.level + 1
    x = qs.bounds.x
    y = qs.bounds.y
    w = qs.bounds.w/2
    h = qs.bounds.h/2
  qs.nodes = @[
    newQuadSpace(Rect(x: x, y: y, w: w, h: h), nextLevel),
    newQuadSpace(Rect(x: x, y: y+h, w: w, h: h), nextLevel),
    newQuadSpace(Rect(x: x+w, y: y, w: w, h: h), nextLevel),
    newQuadSpace(Rect(x: x+w, y: y+h, w: w, h: h), nextLevel)
  ]
  for e in qs.things:
    let index = qs.whichQuadrant(e)
    qs.nodes[index].insert(e)
  qs.things.setLen(0)

proc insert*(qs: QuadSpace, e: Entry) =
  if qs.nodes.len != 0:
    let index = qs.whichQuadrant(e)
    qs.nodes[index].insert(e)
  else:
    qs.things.add e
    if qs.things.len > maxThings and qs.level < maxLevels:
      qs.split()

proc overlaps(qs: QuadSpace, e: Entry, maxRange: float): bool =
  return overlapRectCircle(e.pos, maxRange, qs.bounds.x, qs.bounds.y,
      qs.bounds.w, qs.bounds.h)

iterator findInRangeApprox*(qs: QuadSpace, e: Entry, maxRange: float): Entry =
  var nodes = @[qs]
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
  var nodes = @[qs]
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
  var nodes = @[qs]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        nodes.add(node)
    else:
      for e in qs.things:
        yield e

proc clear*(qs: QuadSpace) {.inline.} =
  qs.nodes.setLen(0)
  qs.things.setLen(0)

proc finalize*(qs: QuadSpace) {.inline.} =
  discard

proc len*(qs: QuadSpace): int {.inline.} =
  var nodes = @[qs]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        nodes.add(node)
    else:
      result += qs.things.len

type KdSpace* = ref object
  ## KD-Tree, each cell is divided vertically or horizontally.
  ## Supposed to be good for large amount of entries.
  things*: seq[Entry]
  nodes*: seq[KdSpace]
  bounds*: Rect
  level*: int

proc newKdSpace*(bounds: Rect, level: int = 0): KdSpace =
  result = KdSpace()
  result.bounds = bounds
  result.level = level

proc insert*(ks: KdSpace, e: Entry) {.inline.} =
  ks.things.add e

proc finalize*(ks: KdSpace) =
  if ks.things.len > maxThings:
    let axis = ks.level mod 2
    ks.things.sort proc(a, b: Entry): int = cmp(a.pos[axis], b.pos[axis])
    let
      b = ks.bounds
      arr1 = ks.things[0 ..< ks.things.len div 2]
      arr2 = ks.things[ks.things.len div 2 .. ^1]
      mid = arr1[^1].pos[axis]
    var
      node1: KdSpace
      node2: KdSpace
    if axis == 0:
      let midW = mid - b.x
      node1 = newKdSpace(rect(b.x, b.y, midW, b.h), ks.level + 1)
      node2 = newKdSpace(rect(mid, b.y, b.w - midW, b.h), ks.level + 1)
    else:
      let midH = mid - b.y
      node1 = newKdSpace(rect(b.x, b.y, b.w, midH), ks.level + 1)
      node2 = newKdSpace(rect(b.x, mid, b.w, b.h - midH), ks.level + 1)
    node1.things = arr1
    node2.things = arr2
    node1.finalize()
    node2.finalize()
    ks.things.setLen(0)
    ks.nodes = @[node1, node2]

proc overlaps(ks: KdSpace, e: Entry, maxRange: float): bool =
  return overlapRectCircle(e.pos, maxRange, ks.bounds.x, ks.bounds.y,
      ks.bounds.w, ks.bounds.h)

iterator findInRangeApprox*(ks: KdSpace, e: Entry, maxRange: float): Entry =
  var nodes = @[ks]
  while nodes.len > 0:
    var ks = nodes.pop()
    if ks.nodes.len == 2:
      for node in ks.nodes:
        if node.overlaps(e, maxRange):
          nodes.add(node)
    else:
      for e in ks.things:
        yield e

iterator findInRange*(ks: KdSpace, e: Entry, maxRange: float): Entry =
  let maxRangeSq = maxRange * maxRange
  var nodes = @[ks]
  while nodes.len > 0:
    var ks = nodes.pop()
    if ks.nodes.len == 2:
      for node in ks.nodes:
        if node.overlaps(e, maxRange):
          nodes.add(node)
    else:
      for thing in ks.things:
        if thing.id != e.id and thing.pos.distSq(e.pos) < maxRangeSq:
          yield thing

iterator all*(ks: KdSpace): Entry =
  var nodes = @[ks]
  while nodes.len > 0:
    var ks = nodes.pop()
    if ks.nodes.len == 2:
      for node in ks.nodes:
        nodes.add(node)
    else:
      for e in ks.things:
        yield e

proc clear*(kd: KdSpace) {.inline.} =
  kd.things.setLen(0)
  kd.nodes.setLen(0)

proc len*(ks: KdSpace): int =
  var nodes = @[ks]
  while nodes.len > 0:
    var ks = nodes.pop()
    if ks.nodes.len == 2:
      for node in ks.nodes:
        nodes.add(node)
    else:
      result += ks.things.len
