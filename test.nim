import eminim, streams, parsejson

type
  Foo = ref object
    value: int
    next: Foo
  Fruit = enum
    Apple, Banana, Orange
  Baz = distinct string
  BarBaz = array[2..8, int]
  BarBar = object
    value: Baz
  Bar = object
    name: string
    case kind: Fruit
    of Banana:
      bad: float
      banana: int
    of Apple: apple: string
    else: discard
  Rejected = object
    val: (int,)

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
block:
  let s = newStringStream("""[0, 1, 2, 3, 4, 5, 6]""")
  let a = s.jsonTo(BarBaz)
  assert a == [0, 1, 2, 3, 4, 5, 6]
#block:
  #proc initFromJson(dst: var Baz; p: var JsonParser) {.borrow.}
  #let s = newStringStream(""" "world" """)
  #let a = s.jsonTo(Baz)
  #assert a == "world"
#block:
  #let s = newStringStream("""{"value": 42}""")
  #let a = s.jsonTo((int,))
  #assert(a[0] == 42)
#block:
  #let s = newStringStream("""{"val": {"value": 42}}""")
  #let a = s.jsonTo(Rejected)
  #assert(a.val[0] == 42)
