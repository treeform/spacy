import spacy, vmath, random

var rand = initRand(2021)

# Create one of the BruteSpace, SortSpace, HashSpace, QuadSpace or KdSpace.
var space = newSortSpace()
for i in 0 ..< 1000:
  # All entries should have a id and pos.
  let e = Entry(id: i.uint32, pos: rand.randVec2())
  # Insert entries.
  space.insert e
# Call finalize to start using the space.
space.finalize()

# Iterate N x N entires and get the closest.
let distance = 0.001
for a in space.all():
  for b in space.findInRange(a, distance):
    echo a, " is close to ", b

# Clear the space when you are done.
space.clear()
