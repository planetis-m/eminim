import ../eminim, fusion/smartptrs, std/[streams, parsejson]

proc storeJson*[T](s: Stream; o: UniquePtr[T]) =
  if o.isNil:
    s.newJNull()
  else:
    storeJson(s, o[])

proc initFromJson*[T](dst: var UniquePtr[T]; p: var JsonParser) =
  if p.tok == tkNull:
    reset(dst)
    discard getTok(p)
  elif p.tok == tkCurlyLe:
    var tmp: T
    initFromJson(tmp, p)
    dst = newUniquePtr(tmp)
  else:
    raiseParseErr(p, "object or null")

proc storeJson*[T](s: Stream; o: SharedPtr[T]) =
  if o.isNil:
    s.newJNull()
  else:
    storeJson(s, o[])

proc initFromJson*[T](dst: var SharedPtr[T]; p: var JsonParser) =
  if p.tok == tkNull:
    reset(dst)
    discard getTok(p)
  elif p.tok == tkCurlyLe:
    var tmp: T
    initFromJson(tmp, p)
    dst = newSharedPtr(tmp)
  else:
    raiseParseErr(p, "object or null")

proc storeJson*[T](s: Stream; o: ConstPtr[T]) = storeJson(s, SharedPtr[T](o))
proc initFromJson*[T](dst: var ConstPtr[T]; p: var JsonParser) = initFromJson(SharedPtr[T](dst), p)
