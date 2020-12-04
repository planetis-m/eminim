# For context see: https://github.com/planetis-m/breakout-ecs

# This datastructures is sort of like a Table[int, T],
# we resort to using arrays for the (key, value) pairs.

proc storeJson*[T](s: Stream; a: Storage[T]) =
   s.write "["
   var comma = false
   for i in 0 ..< a.len:
      if comma: s.write ","
      else: comma = true
      s.write "["
      storeJson(s, a.packedToSparse[i])
      s.write ","
      storeJson(s, a.packed[i])
      s.write "]"
   s.write "]"

proc initFromJson*[T](dst: var Storage[T]; p: var JsonParser) =
   eat(p, tkBracketLe)
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
