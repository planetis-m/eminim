import eminim, streams, parsejson

type
  Foo = ref object
    value: int
    next: Foo
  Fruit = enum
    Apple
    Banana
  Bar = object
    name: string
    case kind: Fruit
    of Banana:
      bad: float
      banana: int
    of Apple: apple: string

block:
  let s = newStringStream("""{"name":"hello","kind":"Apple","apple":"world"}""")
  let a = s.jsonTo(Bar)
  assert a.name == "hello"
  assert a.kind == Apple
  assert a.apple == "world"
block:
  let s = newStringStream("""{"value": 1, "next": {"value": 2, "next": {}}}""")
  let a = s.jsonTo(Foo)
  assert(a != nil and a.value == 1)
  let b = a.next
  assert(b != nil and b.value == 2)
block:
  let s = newStringStream("""{"value": 42}""")
  let a = s.jsonTo(Foo)
  assert(a != nil and a.value == 42)
