# Eminim — JSON deserialization macro for Nim

## About

This package provides a ``jsonTo`` proc which deserializes the specified type from a ``Stream``. It
generates code, in compile time, to use directly the JsonParser, without creating intermediate `JsonNode`.

For example:

```nim
type
  Bar = object
    name: string
    case kind: Fruit
    of Banana:
      bad: float
      banana: int
    of Apple: apple: string

let s = newStringStream("""{"name":"hello","kind":"Apple","apple":"world"}""")
let a = s.jsonTo(Bar)
```

Produces this code:

```nim
proc packImpl(dst: var Bar, p: var JsonParser) =
  eat(p, tkCurlyLe)
  while p.tok != tkCurlyRi:
    if p.tok != tkString:
      raiseParseErr(p, "string literal as key")
    case p.a
    of "name":
      discard getTok(p)
      eat(p, tkColon)
      initFromJson(dst.name, p)
    of "kind":
      discard getTok(p)
      eat(p, tkColon)
      var kindTmp: Fruit
      initFromJson(kindTmp, p)
      dst.kind = kindTmp
      if p.tok != tkComma:
        break
      discard getTok(p)
      if p.tok != tkString:
        raiseParseErr(p, "string literal as key")
      case dst.kind
      of Banana:
        case p.a
        of "bad":
          discard getTok(p)
          eat(p, tkColon)
          initFromJson(dst.bad, p)
        of "banana":
          discard getTok(p)
          eat(p, tkColon)
          initFromJson(dst.banana, p)
        else:
          raiseParseErr(p, "valid object field")
      of Apple:
        case p.a
        of "apple":
          discard getTok(p)
          eat(p, tkColon)
          initFromJson(dst.apple, p)
        else:
          raiseParseErr(p, "valid object field")
    else:
      raiseParseErr(p, "valid object field")
    if p.tok != tkComma:
      break
    discard getTok(p)
  eat(p, tkCurlyRi)

proc pack(s: Stream, t: typedesc[Bar]): Bar =
  var p: JsonParser
  open(p, s, "unknown file")
  try:
    discard getTok(p)
    packImpl(result, p)
    eat(p, tkEof)
  finally:
    close(p)
```
