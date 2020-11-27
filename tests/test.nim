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
  Bar = ref object
    case kind: Fruit
    of Banana:
      bad: float
      banana: int
    of Apple: apple: string
    else: discard
  Rejected = object
    val: (int,)
  ContentNodeKind = enum
    P, Br, Text
  ContentNode = object
    case kind: ContentNodeKind
    of P: pChildren: seq[ContentNode]
    of Br: nil
    of Text: textStr: string
  BazBat = ref object of RootObj
  BarFoo = ref object of BazBat
    t: float
  BazFoo = ref object of BarFoo
  FooBar = ref object of BazFoo
    v: string

block:
  let mynode = ContentNode(kind: P, pChildren: @[
    ContentNode(kind: Text, textStr: "mychild"),
    ContentNode(kind: Br)
  ])
  let s = newStringStream("""{"kind":"P","pChildren":[{"kind":"Text","textStr":"mychild"},{"kind":"Br"}]}""")
  let a = s.jsonTo(ContentNode)
  assert $a == $mynode
block:
  let s = newStringStream("""{"kind":"Apple","apple":"world"}""")
  let a = s.jsonTo(Bar)
  assert a.kind == Apple
  assert a.apple == "world"
block:
  let s = newStringStream("""{"value":1,"next":{"value":2,"next":{}}}""")
  let a = s.jsonTo(Foo)
  assert a.value == 1
  let b = a.next
  assert b.value == 2
block:
  let s = newStringStream("""{"value": 42}""")
  let a = s.jsonTo(Foo)
  assert(a != nil and a.value == 42)
block:
  let s = newStringStream("""[0, 1, 2, 3, 4, 5, 6]""")
  let a = s.jsonTo(BarBaz)
  assert a == [0, 1, 2, 3, 4, 5, 6]
block:
  let s = newStringStream("""{"v":"hello","t":1.0}""")
  let a = s.jsonTo(FooBar)
  assert a.v == "hello"
  assert a.t == 1.0
#block:
  #proc initFromJson(dst: var Baz; p: var JsonParser) {.borrow.}
  #let s = newStringStream(""" "world" """)
  #let a = s.jsonTo(Baz)
  #assert a.string == "world"
#block:
  #let s = newStringStream("""{"value": 42}""")
  #let a = s.jsonTo((int,))
  #assert(a[0] == 42)
#block:
  #let s = newStringStream("""{"val": {"value": 42}}""")
  #let a = s.jsonTo(Rejected)
  #assert(a.val[0] == 42)
