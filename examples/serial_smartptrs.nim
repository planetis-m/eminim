import eminim, fusion/smartpts

proc storeJson*[T](s: Stream; o: UniquePtr[T]) =
   ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
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
