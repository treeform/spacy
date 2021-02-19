import pixie, random, spacy, strformat, tables, times, vmath

let radius = 100.0

proc strokeCircle*(
  image: Image,
  center: Vec2,
  radius: float32,
  color: ColorRGBA,
  strokeWidth: float32 = 1.0,
  blendMode = bmNormal
) =
  var path: Path
  path.ellipse(center, radius, radius)
  image.strokePath(path, color, blendMode=blendMode, strokeWidth=strokeWidth)

proc strokeRect*(
  image: Image,
  rect: Rect,
  color: ColorRGBA,
  strokeWidth: float32 = 1.0,
  blendMode = bmNormal
) =
  var path: Path
  path.rect(rect)
  image.strokePath(path, color, blendMode=blendMode, strokeWidth=strokeWidth)

proc drawInternal(image: Image, bs: BruteSpace, at: Entry) =
  discard

proc drawInternal(image: Image, ss: SortSpace, at: Entry) =
  image.drawRect(
    rect(at.pos.x - radius, 0, radius*2, 1000),
    rgba(255, 255, 255, 25).toPremultipliedAlpha()
  )

proc drawInternal(image: Image, qn: QuadNode, at: Entry) =
  for node in qn.nodes:
    let b = node.bounds
    if node.nodes.len == 0 and overlaps(circle(at.pos, radius), b):
      image.drawRect(b, rgba(255, 255, 255, 25).toPremultipliedAlpha())
    else:
      image.strokeRect(b, rgba(255, 255, 255, 25).toPremultipliedAlpha())
    image.drawInternal(node, at)

proc drawInternal(image: Image, qs: QuadSpace, at: Entry) =
  image.drawInternal(qs.root, at)

proc drawInternal(image: Image, kn: KdNode, at: Entry) =
  for node in kn.nodes:
    let b = node.bounds
    if node.nodes.len == 0 and overlaps(circle(at.pos, radius), b):
      image.drawRect(b, rgba(255, 255, 255, 25).toPremultipliedAlpha())
    else:
      image.strokeRect(b, rgba(255, 255, 255, 25).toPremultipliedAlpha())

    image.drawInternal(node, at)

proc drawInternal(image: Image, ks: KdSpace, at: Entry) =
  image.drawInternal(ks.root, at)

proc drawInternal(image: Image, hs: HashSpace, at: Entry) =
  let r = hs.resolution
  for key in hs.hash.keys:
    let b = rect(float32(key[0])*r, float32(key[1])*r, r, r)
    if overlaps(circle(at.pos, radius), b):
      image.drawRect(b, rgba(255, 255, 255, 25).toPremultipliedAlpha())
    else:
      image.strokeRect(b, rgba(255, 255, 255, 25).toPremultipliedAlpha())

template testSpace(name: string, space: untyped) =
  echo "---------------- ", name

  var at: Entry

  var rand = initRand(2021)

  for i in 0 ..< 1000:
    let e = Entry(id: uint32 i, pos: rand.randVec2() * 500 + vec2(500, 500))
    space.insert e
    if i == 0:
      at = e
  space.finalize()

  var image = newImage(1000, 1000)
  image.fill(color(0.11, 0.14, 0.42).rgba)

  image.drawInternal(space, at)

  for e in space.all:
    image.drawCircle(e.pos, 1, rgba(255, 255, 255, 255))

  for e in space.findInRangeApprox(at, radius):
    image.drawCircle(e.pos, 2, rgba(255, 255, 255, 255))

  for e in space.findInRange(at, radius):
    image.drawCircle(e.pos, 3, rgba(0, 255, 0, 255))

  image.drawCircle(at.pos, 3, rgba(255, 0, 0, 255))
  image.strokeCircle(at.pos, radius, rgba(255, 255, 255, 255))

  image.writeFile("examples/" & name & ".png")

var bs = newBruteSpace()
testSpace("BruteSpace", bs)

var ss = newSortSpace()
testSpace("SortSpace", ss)

var hs = newHashSpace(radius)
testSpace("HashSpace", hs)

var qs = newQuadSpace(rect(0, 0, 1000.0, 1000.0))
testSpace("QuadSpace", qs)

var ks = newKdSpace(rect(0, 0, 1000.0, 1000.0))
testSpace("KdSpace", ks)
