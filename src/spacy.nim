import algorithm, bumpy, math, tables, vmath

type Entry* = object
  id*: uint32
  pos*: Vec2

type BruteSpace* = ref object
  ## Brute-force space just compares every entry vs every other entry.
  ## Supposed to be good for very small number or large ranges.
  list*: seq[Entry]

proc newBruteSpace*(): BruteSpace =
  ## Creates a new brute-force space.
  result = BruteSpace()
  result.list = newSeq[Entry]()

proc insert*(bs: BruteSpace, e: Entry) {.inline.} =
  ## Adds entry to the space.
  bs.list.add e

proc finalize*(bs: BruteSpace) {.inline.} =
  ## Finishes the space and makes it ready for use.
  discard

proc clear*(bs: BruteSpace) {.inline.} =
  ## Clears the spaces and makes it ready to be used again.
  bs.list.setLen(0)

proc len*(bs: BruteSpace): int {.inline.} =
  ## Number of entries inserted
  bs.list.len

iterator all*(bs: BruteSpace): Entry =
  ## Iterates all entries in a space.
  for e in bs.list:
    yield e

iterator findInRangeApprox*(bs: BruteSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry but does not cull them.
  ## Useful if you need distance anyways and will compute other computations.
  for thing in bs.list:
    yield thing

iterator findInRange*(bs: BruteSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry.
  let radiusSq = radius * radius
  for thing in bs.findInRangeApprox(e, radius):
    if e.id != thing.id and e.pos.distSq(thing.pos) < radiusSq:
      yield thing

type SortSpace* = ref object
  ## Sort space sorts all entires on one axis X.
  ## Supposed to be good for very small ranges.
  list*: seq[Entry]

proc newSortSpace*(): SortSpace =
  ## Creates a new sorted space.
  result = SortSpace()
  result.list = newSeq[Entry]()

proc insert*(ss: SortSpace, e: Entry) {.inline.} =
  ## Adds entry to the space.
  ss.list.add e

proc sortSpaceCmp(a, b: Entry): int =
  cmp(a.pos.x, b.pos.x)

proc finalize*(ss: SortSpace) {.inline.} =
  ## Finishes the space and makes it ready for use.
  ss.list.sort(sortSpaceCmp)

proc clear*(ss: SortSpace) {.inline.} =
  ## Clears the spaces and makes it ready to be used again.
  ss.list.setLen(0)

proc len*(ss: SortSpace): int {.inline.} =
  ## Number of entries inserted.
  ss.list.len

iterator all*(ss: SortSpace): Entry =
  ## Iterates all entries in a space.
  for e in ss.list:
    yield e

iterator findInRangeApprox*(ss: SortSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry but does not cull them.
  ## Useful if you need distance anyways and will compute other computations.
  let
    l = ss.list

  # find index of entry
  let index = ss.list.lowerBound(e, sortSpaceCmp)

  # scan to the right
  var right = index
  while right < l.len:
    let thing = l[right]
    if thing.pos.x - e.pos.x > radius:
      break
    if thing.id != e.id:
      yield thing
    inc right

  # scan to the left
  var left = index - 1
  while left >= 0:
    let thing = l[left]
    if e.pos.x - thing.pos.x > radius:
      break
    yield thing
    dec left

iterator findInRange*(ss: SortSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry.
  let radiusSq = radius * radius
  for thing in ss.findInRangeApprox(e, radius):
    if e.id != thing.id and e.pos.distSq(thing.pos) < radiusSq:
      yield thing

type HashSpace* = ref object
  ## Divides space into little tiles that objects are hashed too.
  ## Supposed to be good for very uniform filled space.
  hash*: TableRef[(int32, int32), seq[Entry]]
  resolution*: float

proc newHashSpace*(resolution: float): HashSpace =
  ## Creates a hash table space.
  result = HashSpace()
  result.hash = newTable[(int32, int32), seq[Entry]]()
  result.resolution = resolution

proc hashSpaceKey(hs: HashSpace, e: Entry): (int32, int32) =
  (int32(floor(e.pos.x / hs.resolution)), int32(floor(e.pos.y / hs.resolution)))

proc insert*(hs: HashSpace, e: Entry) =
  ## Adds entry to the space.
  let key = hs.hashSpaceKey(e)
  if key in hs.hash:
    hs.hash[key].add(e)
  else:
    hs.hash[key] = @[e]

proc finalize*(hs: HashSpace) {.inline.} =
  ## Finishes the space and makes it ready for use.
  discard

proc clear*(hs: HashSpace) {.inline.} =
  ## Clears the spaces and makes it ready to be used again.
  hs.hash.clear()

proc len*(hs: HashSpace): int {.inline.} =
  ## Number of entries inserted
  for list in hs.hash.values:
    result += list.len

iterator all*(hs: HashSpace): Entry =
  ## Iterates all entries in a space.
  for list in hs.hash.values:
    for e in list:
      yield e

iterator findInRangeApprox*(hs: HashSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry but does not cull them.
  ## Useful if you need distance anyways and will compute other computations.
  let
    d = int(radius / hs.resolution) + 1
    px = int(e.pos.x / hs.resolution)
    py = int(e.pos.y / hs.resolution)

  for x in -d .. d:
    for y in -d .. d:
      let
        rx = px + x
        ry = py + y
      if circle(e.pos, radius).overlaps(rect(
          float(rx) * hs.resolution,
          float(ry) * hs.resolution,
          hs.resolution,
          hs.resolution
        )):
        let posKey = (int32 rx, int32 ry)
        if posKey in hs.hash:
          for thing in hs.hash[posKey]:
            if thing.id != e.id:
              yield thing

iterator findInRange*(hs: HashSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry.
  let radiusSq = radius * radius
  for thing in hs.findInRangeApprox(e, radius):
    if e.id != thing.id and e.pos.distSq(thing.pos) < radiusSq:
      yield thing

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
  ## Creates a new quad-tree space.
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

proc insert(qs: QuadSpace, qn: var QuadNode, e: Entry) =
  if qn.nodes.len != 0:
    let index = qn.whichQuadrant(e)
    qs.insert(qn.nodes[index], e)
  else:
    qn.things.add e
    if qn.things.len > qs.maxThings and qn.level < qs.maxLevels:
      qs.split(qn)

proc insert*(qs: QuadSpace, e: Entry) =
  ## Adds entry to the space.
  qs.insert(qs.root, e)

proc finalize*(qs: QuadSpace) {.inline.} =
  ## Finishes the space and makes it ready for use.
  discard

proc clear*(qs: QuadSpace) {.inline.} =
  ## Clears the spaces and makes it ready to be used again.
  qs.root.nodes.setLen(0)
  qs.root.things.setLen(0)

proc len*(qs: QuadSpace): int {.inline.} =
  ## Number of entries inserted.
  var nodes = @[qs.root]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        nodes.add(node)
    else:
      result += qs.things.len

iterator all*(qs: QuadSpace): Entry =
  ## Iterates all entries in a space.
  var nodes = @[qs.root]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        nodes.add(node)
    else:
      for e in qs.things:
        yield e

iterator findInRangeApprox*(qs: QuadSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry but does not cull them.
  ## Useful if you need distance anyways and will compute other computations.
  var nodes = @[qs.root]
  while nodes.len > 0:
    var qs = nodes.pop()
    if qs.nodes.len == 4:
      for node in qs.nodes:
        if circle(e.pos, radius).overlaps(node.bounds):
          nodes.add(node)
    else:
      for e in qs.things:
        yield e

iterator findInRange*(qs: QuadSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry.
  let radiusSq = radius * radius
  for thing in qs.findInRangeApprox(e, radius):
    if e.id != thing.id and e.pos.distSq(thing.pos) < radiusSq:
      yield thing

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

proc newKdNode(bounds: Rect, level: int): KdNode =
  result = KdNode()
  result.bounds = bounds
  result.level = level

proc newKdSpace*(bounds: Rect, maxThings = 10, maxLevels = 10): KdSpace =
  ## Creates a new space based on kd-tree.
  result = KdSpace()
  result.root = newKdNode(bounds, 0)
  result.maxThings = maxThings

proc insert*(ks: KdSpace, e: Entry) {.inline.} =
  ## Adds entry to the space.
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
  ## Finishes the space and makes it ready for use.
  ks.finalize(ks.root)

proc clear*(ks: KdSpace) {.inline.} =
  ## Clears the spaces and makes it ready to be used again.
  ks.root.things.setLen(0)
  ks.root.nodes.setLen(0)

proc len*(ks: KdSpace): int =
  ## Number of entries inserted.
  var nodes = @[ks.root]
  while nodes.len > 0:
    var kn = nodes.pop()
    if kn.nodes.len == 2:
      for node in kn.nodes:
        nodes.add(node)
    else:
      result += kn.things.len

iterator all*(ks: KdSpace): Entry =
  ## Iterates all entries in a space.
  var nodes = @[ks.root]
  while nodes.len > 0:
    var kn = nodes.pop()
    if kn.nodes.len == 2:
      for node in kn.nodes:
        nodes.add(node)
    else:
      for e in kn.things:
        yield e

iterator findInRangeApprox*(ks: KdSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry but does not cull them.
  ## Useful if you need distance anyways and will compute other computations.
  var nodes = @[ks.root]
  while nodes.len > 0:
    var kn = nodes.pop()
    if kn.nodes.len == 2:
      for node in kn.nodes:
        if circle(e.pos, radius).overlaps(node.bounds):
          nodes.add(node)
    else:
      for e in kn.things:
        yield e

iterator findInRange*(ks: KdSpace, e: Entry, radius: float): Entry =
  ## Iterates all entries in range of an entry.
  let radiusSq = radius * radius
  for thing in ks.findInRangeApprox(e, radius):
    if e.id != thing.id and e.pos.distSq(thing.pos) < radiusSq:
      yield thing
