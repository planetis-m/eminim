# Eminim — JSON deserialization macro for Nim

## About

This package provides a ``to`` macro which deserializes the specified type from a ``Stream``. It
generates code, in compile time, to use directly the JsonParser, without creating intermediate JsonNode(s).

For example:

```nim
   type Foo = ref object
      value: int
   let s = newStringStream("{\"value\": 1}")
   let a = s.to(Foo)
```

Produces this code:

```nim
   proc packImpl(p: var JsonParser): Foo =
      new(result)
      eat(p, tkCurlyLe)
      while p.tok != tkCurlyRi:
         if p.tok != tkString:
            raiseParseErr(p, "string literal as key")
         case p.a
         of "value":
            discard getTok(p)
            eat(p, tkColon)
            if p.tok == tkInt:
               result.value = int(parseInt(p.a))
               discard getTok(p)
            else:
               raiseParseErr(p, "int")
         else:
            raiseParseErr(p, "object field")
         if p.tok != tkComma:
            break
         discard getTok(p)
      eat(p, tkCurlyRi)

   proc pack(s: Stream): Foo =
      var p: JsonParser
      open(p, s, "unknown file")
      try:
         discard getTok(p)
         result = packImpl(p)
         eat(p, tkEof)
      finally:
         close(p)

   pack(s)
```
