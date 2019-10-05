# Eminim — JSON deserialization macro for Nim

## About

This package provides a ``to`` macro which deserializes the specified type from a ``Stream``. It
generates code, in compile time, to use directly the JsonParser, without creating intermediate JsonNode(s).

For example:

```nim
   let s = newStringStream("{\"value\": 1}")
   let a = s.to(Foo)
```

Produces this code:

```nim
   proc pack_303206(s`gensym303222: Stream): Colors =
   var p_303207: JsonParser
   open(p_303207, s`gensym303222, "unknown file")
   discard getTok(p_303207)
   eat(p_303207, tkCurlyLe)
   while p_303207.tok != tkCurlyRi:
      if p_303207.tok != tkString:
         raiseParseErr(p_303207, "string literal as key")
      let key_303220 = move(p_303207.a)
      discard getTok(p_303207)
      eat(p_303207, tkColon)
      case key_303220
      of "value":
         if p_303207.tok ==
            tkInt:
         result.value = int(parseInt(p_303207.a))
         discard getTok(p_303207)
         else:
         raiseParseErr(p_303207, "int")
      else:
         raiseParseErr(p_303207, "object field")
      if p_303207.tok != tkComma:
         break
      discard getTok(p_303207)
   eat(p_303207, tkCurlyRi)
   eat(p_303207, tkEof)
   close(p_303207)

   pack_303206(s)
```
