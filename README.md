# Eminim — JSON marshal module for Nim
## About

This package provides the ``jsonTo``, ``loadJson`` procs and ``jsonItems`` iterator which deserializes
the specified type from a ``Stream``. The `storeJson` procs are used to write the JSON
representation of a location into a `Stream`. Low level `initFromJson` and `storeJson`
procs can be overloaded, in order to support arbitary container types, i.e.
[jsmartptrs.nim](eminim/jsmartptrs.nim).

## Usage
```nim
import std/streams, eminim

type
  Foo = ref object
    value: int
    next: Foo

let d = Foo(value: 1, next: Foo(value: 2, next: nil))
let s = newStringStream()
# Make a roundtrip
s.storeJson(d) # writes JSON from a location
s.setPosition(0)
let a = s.jsonTo(Foo) # reads JSON and transform to a type
# Alternatively load directly into a location
s.setPosition(0)
var a: Foo
s.loadJson(a)
```

## Features
- Serializing and deserializing directly into `Streams`. For common usage it is done automatically.
  Generally speaking intervation is needed when working with `ptr` types.
- Supports `options`, `sets` and `tables` by default.
- Strict field checking can be disabled at compile-time with `-d:eminimLenient`.
  Meaning you can parse complex JSON structures like the `World Bank dataset` and
  retrieve only the fields you're interested.
- Uses nim identifier equality algorithm to compare JSON fields.
  Which means fields written in camelCase or snake_case are equal.
- Overloading serialization procs. See [jsonprocs.nim](examples/jsonprocs.nim)

## How it works
It generates code, in compile time, to use directly the JsonParser, without creating an
intermediate `JsonNode` tree.

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
      dst = (typeof dst)(kind: kindTmp`gensym0)
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

## The jsonItems iterator
Inspired by the [Machine Learning over JSON](https://www.naftaliharris.com/blog/machine-learning-json/)
article, I originally designed `eminim` as a way to parse JSON datasets directly into Tensors.
It's still very capable in this application.

```nim
type
  IrisPlant = object
    sepalLength: float32
    sepalWidth: float32
    petalLength: float32
    petalWidth: float32
    species: string

let fs = newFileStream("iris.json")
for x in jsonItems(fs, IrisPlant):
  # you have read an item from the iris dataset,
  # use it to create a Tensor
```

## Limitations
- Limited support of object variants. The discriminant field is expected first.
  Also there can be no fields before and after the case section.
  In all other cases it fails with a `JsonParserError`. This limitation is hard to improve.
  The current state might fit some use-cases and it's better than nothing.
- Borrowing proc `initFromJson[T](dst: var T; p: var JsonParser)` for distinct types isn't
  currently working. Blocked by a Nim bug. Use overloads for now.
- Custom pragmas are not supported. Unless `hasCustomPragma` improves, this feature won't be added.
  You can currently substitute skipped fields by creating empty overloads.

## Acknowledgements
- Thanks to @krux02 for his review and valuable feedback. This rewrite wouldn't be possible without his work on `json.to`.
