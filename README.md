# Spatial data structures for Nim.

Spatial algorithms find "closest" things faster than simple brute force iteration would. They make your code run faster using smarter data structures. This library has different "Spaces" that you can use to speed up games and graphical applications.

One key design decision is that all spaces have a very similar API and can be easily swapped. This way you can swap out spaces and see which one works best for your use case.

### Perf time (1000 vs 1000 at 0.001 distance):
```
BruteSpace ......................... 1.839 ms      1.869 ms    ±0.052   x100
SortSpace .......................... 1.511 ms      1.539 ms    ±0.028   x100
HashSpace .......................... 0.441 ms      0.457 ms    ±0.022   x100
QuadSpace .......................... 0.185 ms      0.195 ms    ±0.010   x100
KdSpace ............................ 0.519 ms      0.548 ms    ±0.037   x100
```

You would usually pick the best one for your usecase by profiling and tuning. There is a cost to generating each space, you need to make sure it justifies the lookup time savings.

# BruteSpace

BruteSpace is basically a brute force algorithm that takes every inserted element and compares to every other inserted element.

![examples/BruteSpace.png](examples/BruteSpace.png)

The BruteSpace is faster is when there are like less elements in the space or you don't do many look ups. It’s a good baseline space that enables you to see how slow things actually can be. Don't discount it! Linear scans are pretty fast when you are just zipping through memory. Brute force might be all you need!

# SortSpace

SortSpace is probably the simplest spatial algorithm you can have. All it does is sorts all entries on one axis. Here it does the X axis. Then all it does is looks to the right and the left for matches. It’s very simple to code and produces good results when the radius is really small.

![examples/SortSpace.png](examples/SortSpace.png)

You can see we are checking way less elements compared to BruteSpace. Instead of checking vs all elements we are only checking in the vertical slice.

SortSpace draws its power from the underlying sorting algorithm n×log(n) nature. It’s really good for very small distances when you don’t expect many elements to appear in the vertical slice. SortSpace is really good at cache locality because you are searching things next to each other and are walking linearly in memory.

# HashSpace

HashSpace is a little more complex than SortSpace but it’s still pretty simple. Instead of drawing the power from a sorting algorithm it draws its power from hashtables. HashSpace has a resolution and every entry going in is put into a grid-bucket. To check for surrounding entries you simply look up closest grid buckets and then loop through their entries.

![examples/HashSpace.png](examples/HashSpace.png)

HashSpaces are really good for when your entries are uniformly distributed with even density and things can’t really bunch up too much. They work even better when entries are really far apart. They are also really good when you are always searching the same distance in that you can make the grid size match your search radius. You can tune this space for your usecase.

# QuadSpace

QuadSpace is basically the same as "quad tree" (I just like the space theme). Quad trees are a little harder to make but usually winners in all kinds of spatial applications. They work by starting out with a single quad and as more elements are inserted into the quad they hit maximum elements in a quad and split into 4. The elements are redistributed. As those inner quads begin to fill up they are split as well. When looking up stuff you just have to walk into the closets quads.

![examples/QuadSpace.png](examples/QuadSpace.png)

QuadSpaces are really good at almost everything. But they might miss out in some niche cases where SortSpaces (really small distances) or HashSpaces (uniform density) might win out. They are also bad at cache locality as many pointers or references might make you jump all over the place.

# KdSpace

Just like QuadSpace is about Quad Trees, KdSpace is about kd-tree. Kd-Trees different from quad trees in that they are binary and they sort their results as they divide. Potentially getting less nodes and less bounds to check. Quad trees build their nodes as new elements are inserted while kd-trees build all the nodes in one big final step.

![examples/KdSpace.png](examples/KdSpace.png)

KdSpace trees take a long time to build. In theory KdSpace would be good when the entries are static, the tree is built once and used often. While QuadSpace might be better when the tree is rebuilt all the time.

# Always be profiling.

You can’t really say one Space is faster than the other you always need to check. The hardware or your particular problem might drastically change the speed characteristics. This is why all spaces have a similar API and you can just swap them out when another space seems better for your use case.

# API: spacy

```nim
import spacy
```

## **type** Entry


```nim
Entry = object
 id*: uint32
 pos*: Vec2
```

## **type** BruteSpace

Brute space just compares every entry vs every other entry. Supposed to be good for very small number or large ranges.

```nim
BruteSpace = ref object
 list*: seq[Entry]
```

## **proc** newBruteSpace


```nim
proc newBruteSpace(): BruteSpace
```

## **proc** insert


```nim
proc insert(bs: BruteSpace; e: Entry) {.inline.}
```

## **proc** finalize


```nim
proc finalize(bs: BruteSpace) {.inline.}
```

## **iterator** all


```nim
iterator all(bs: BruteSpace): Entry
```

## **iterator** findInRange


```nim
iterator findInRange(bs: BruteSpace; e: Entry; maxRange: float): Entry
```

## **iterator** findInRangeApprox


```nim
iterator findInRangeApprox(bs: BruteSpace; e: Entry; maxRange: float): Entry
```

## **proc** clear


```nim
proc clear(bs: BruteSpace) {.inline.}
```

## **proc** len


```nim
proc len(bs: BruteSpace): int {.inline.}
```

## **type** SortSpace

Sort space sorts all entires on one axis X. Supposed to be good for very small ranges.

```nim
SortSpace = ref object
 list*: seq[Entry]
```

## **proc** newSortSpace


```nim
proc newSortSpace(): SortSpace
```

## **proc** insert


```nim
proc insert(ss: SortSpace; e: Entry) {.inline.}
```

## **proc** finalize


```nim
proc finalize(ss: SortSpace) {.inline.}
```

## **iterator** all


```nim
iterator all(ss: SortSpace): Entry
```

## **iterator** findInRange


```nim
iterator findInRange(ss: SortSpace; e: Entry; maxRange: float): Entry
```

## **iterator** findInRangeApprox


```nim
iterator findInRangeApprox(ss: SortSpace; e: Entry; maxRange: float): Entry
```

## **proc** clear


```nim
proc clear(ss: SortSpace) {.inline.}
```

## **proc** len


```nim
proc len(ss: SortSpace): int {.inline.}
```

## **type** HashSpace

Divides space into little tiles that objects are hashed too. Supposed to be good for very uniform filled space.

```nim
HashSpace = ref object
 hash*: TableRef[(int32, int32), seq[Entry]]
 resolution*: float
```

## **proc** newHashSpace


```nim
proc newHashSpace(resolution: float): HashSpace
```

## **proc** insert


```nim
proc insert(hs: HashSpace; e: Entry) {.raises: [KeyError].}
```

## **iterator** all


```nim
iterator all(hs: HashSpace): Entry
```

## **iterator** findInRangeApprox


```nim
iterator findInRangeApprox(hs: HashSpace; e: Entry; maxRange: float): Entry {.raises: [KeyError].}
```

## **iterator** findInRange


```nim
iterator findInRange(hs: HashSpace; e: Entry; maxRange: float): Entry {.raises: [KeyError].}
```

## **proc** clear


```nim
proc clear(hs: HashSpace) {.inline.}
```

## **proc** finalize


```nim
proc finalize(hs: HashSpace) {.inline.}
```

## **proc** len


```nim
proc len(hs: HashSpace): int {.inline.}
```

## **type** QuadSpace

QuadTree, divide each node down if there is many elements. Supposed to be for large amount of entries.

```nim
QuadSpace = ref object
 root*: QuadNode
 maxThings*: int
 maxLevels*: int
```

## **type** QuadNode


```nim
QuadNode = ref object
 things*: seq[Entry]
 nodes*: seq[QuadNode]
 bounds*: Rect
 level*: int
```

## **proc** newQuadSpace


```nim
proc newQuadSpace(bounds: Rect; maxThings = 10; maxLevels = 10): QuadSpace
```

## **proc** insert


```nim
proc insert(qs: QuadSpace; qn: var QuadNode; e: Entry) {.raises: [Exception], tags: [RootEffect].}
```

## **proc** insert


```nim
proc insert(qs: QuadSpace; e: Entry) {.raises: [Exception], tags: [RootEffect].}
```

## **iterator** findInRangeApprox


```nim
iterator findInRangeApprox(qs: QuadSpace; e: Entry; maxRange: float): Entry
```

## **iterator** findInRange


```nim
iterator findInRange(qs: QuadSpace; e: Entry; maxRange: float): Entry
```

## **iterator** all


```nim
iterator all(qs: QuadSpace): Entry
```

## **proc** clear


```nim
proc clear(qs: QuadSpace) {.inline.}
```

## **proc** finalize


```nim
proc finalize(qs: QuadSpace) {.inline.}
```

## **proc** len


```nim
proc len(qs: QuadSpace): int {.inline.}
```

## **type** KdSpace

KD-Tree, each cell is divided vertically or horizontally. Supposed to be good for large amount of entries.

```nim
KdSpace = ref object
 root*: KdNode
 maxThings*: int
```

## **type** KdNode


```nim
KdNode = ref object
 things*: seq[Entry]
 nodes*: seq[KdNode]
 bounds*: Rect
 level*: int
```

## **proc** newKdNode


```nim
proc newKdNode(bounds: Rect; level: int): KdNode
```

## **proc** newKdSpace


```nim
proc newKdSpace(bounds: Rect; maxThings = 10; maxLevels = 10): KdSpace
```

## **proc** insert


```nim
proc insert(ks: KdSpace; e: Entry) {.inline.}
```

## **proc** finalize


```nim
proc finalize(ks: KdSpace)
```

## **iterator** findInRangeApprox


```nim
iterator findInRangeApprox(ks: KdSpace; e: Entry; maxRange: float): Entry
```

## **iterator** findInRange


```nim
iterator findInRange(ks: KdSpace; e: Entry; maxRange: float): Entry
```

## **iterator** all


```nim
iterator all(ks: KdSpace): Entry
```

## **proc** clear


```nim
proc clear(ks: KdSpace) {.inline.}
```

## **proc** len


```nim
proc len(ks: KdSpace): int
```
