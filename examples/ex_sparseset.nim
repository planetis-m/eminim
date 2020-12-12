# For context see: https://github.com/planetis-m/breakout-ecs

# This datastructures is like a Table[int, T],
# we resort to using arrays for the (key, value) pairs.

proc storeJson*[T](s: Stream; a: SparseSet[T]) =
  s.write "["
  var comma = false
  for e, val in a.pairs:
    if comma: s.write ","
    else: comma = true
    s.write "["
    storeJson(s, e)
    s.write ","
    storeJson(s, val)
    s.write "]"
  s.write "]"

proc initFromJson*[T](dst: var SparseSet[T]; p: var JsonParser) =
  eat(p, tkBracketLe)
  dst = initSparseSet[T]()
  while p.tok != tkBracketRi:
    eat(p, tkBracketLe)
    var e: Entity
    initFromJson(e, p)
    eat(p, tkComma)
    var val: T
    initFromJson(val, p)
    dst[e] = val
    eat(p, tkBracketRi)
    if p.tok != tkComma: break
    discard getTok(p)
  eat(p, tkBracketRi)
