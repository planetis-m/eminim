# Eminim — JSON deserialization macro for Nim

## About

This package provides a ``jsonTo`` proc which deserializes the specified type from a ``Stream``. It
generates code, in compile time, to use directly the JsonParser, without creating intermediate `JsonNode`.

For example:

```nim
type
  Bar = object
    case kind: Fruit
    of Banana:
      bad: float
      banana: int
    of Apple: apple: string

let s = newStringStream("""{"kind":"Apple","apple":"world"}""")
let a = s.jsonTo(Bar)
```

Produces this code:

```nim
proc initFromJson(dst: var Bar, p: var JsonParser) =
  eat(p, tkCurlyLe)
  while p.tok != tkCurlyRi:
    if p.tok != tkString:
      raiseParseErr(p, "string literal as key")
    case p.a
    of "kind":
      discard getTok(p)
      eat(p, tkColon)
      var kindTmp`gensym0: Fruit
      initFromJson(kindTmp`gensym0, p)
      dst.kind = kindTmp`gensym0
      if p.tok != tkComma:
        break
      discard getTok(p)
      while p.tok != tkCurlyRi:
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
        if p.tok != tkComma:
          break
        discard getTok(p)
    else:
      raiseParseErr(p, "valid object field")
    if p.tok != tkComma:
      break
    discard getTok(p)
  eat(p, tkCurlyRi)

proc jsonTo(s: Stream, t: typedesc[Bar]): Bar =
  var p: JsonParser
  open(p, s, "unknown file")
  try:
    discard getTok(p)
    initFromJson(result, p)
    eat(p, tkEof)
  finally:
    close(p)
```

## Limitations
- Limited support of object variants. The discriminant field is expected first.
  Also there can be no more fields after the case branches.
  In all other cases it fails with a `JsonParserError`. This limitation is hard to improve.
  The current state might fit some use-cases and it's better than nothing.
- Distinct types are supposed to work by overloading (or borrowing) proc `initFromJson[T](dst: var T; p: var JsonParser)`.
  Not currently working. Blocked by a Nim bug.
- Custom pragmas are not supported. Unless `hasCustomPragma` improves, this feature won't be added.

## Acknowledgements
- Thanks @krux02 for his review and valuable feedback. This rewrite wouldn't be possible without his work on `json.to`.
