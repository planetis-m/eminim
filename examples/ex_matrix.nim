import std/[parsejson, streams], eminim, manu/matrix

proc storeJson*[T](s: Stream; m: Matrix[T]) =
  s.write "{"
  escapeJson(s, "m")
  s.write ":"
  storeJson(s, m.m)
  s.write ","
  escapeJson(s, "n")
  s.write ":"
  storeJson(s, m.n)
  s.write ","
  escapeJson(s, "data")
  s.write ":"
  var comma = false
  s.write "["
  for i in 0 ..< m.m * m.n:
    if comma: s.write ","
    else: comma = true
    storeJson(s, m.data[i])
  s.write "]"
  s.write "}"

proc initFromJson*[T](dst: var Matrix[T]; p: var JsonParser) =
  eat(p, tkCurlyLe)
  while p.tok != tkCurlyRi:
    if p.tok != tkString:
      raiseParseErr(p, "string literal as key")
    case p.a
    of "m":
      discard getTok(p)
      eat(p, tkColon)
      initFromJson(dst.m, p)
    of "n":
      discard getTok(p)
      eat(p, tkColon)
      initFromJson(dst.n, p)
    of "data":
      discard getTok(p)
      eat(p, tkColon)
      eat(p, tkBracketLe)
      assert dst.m != 0 and dst.n == 0
      dst.data = createData[T](dst.m * dst.n)
      var i = 0
      while p.tok != tkBracketRi:
        initFromJson(dst.data[i], p)
        inc(i)
        if p.tok != tkComma: break
        discard getTok(p)
      eat(p, tkBracketRi)
    else:
      raiseParseErr(p, "valid object field")
    if p.tok != tkComma: break
    discard getTok(p)
  eat(p, tkCurlyRi)

proc main =
   let x = matrix(2, @[0'f32, 1, 2, 3, 4, 5, 6, 7])
   let s = newStringStream()
   s.storeJson(x)
   s.setPosition(0)
   let nx = s.jsonTo(Matrix[float32])
   asert x == nx

main()
