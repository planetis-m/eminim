import streams, strutils, options, tables, sets

proc escapeJsonUnquoted*(x: string; s: Stream) =
  ## Converts a string `s` to its JSON representation without quotes.
  ## Appends to ``result``.
  for c in x:
    case c
    of '\L': s.write("\\n")
    of '\b': s.write("\\b")
    of '\f': s.write("\\f")
    of '\t': s.write("\\t")
    of '\v': s.write("\\u000b")
    of '\r': s.write("\\r")
    of '"': s.write("\\\"")
    of '\0'..'\7': s.write("\\u000" & $ord(c))
    of '\14'..'\31': s.write("\\u00" & toHex(ord(c), 2))
    of '\\': s.write("\\\\")
    else: s.write(c)

proc escapeJson*(s: Stream; x: string) =
  ## Converts a string `s` to its JSON representation with quotes.
  ## Appends to ``result``.
  s.write("\"")
  escapeJsonUnquoted(x, s)
  s.write("\"")

proc newJNull*(s: Stream) =
  ## Creates a new `JNull JsonNode`.
  s.write "null"

proc jsonFrom*(s: Stream; x: string) =
  ## Creates a new `JString JsonNode`.
  escapeJson(s, x)

proc jsonFrom*(s: Stream; n: BiggestInt) =
  ## Creates a new `JInt JsonNode`.
  s.write $n

proc jsonFrom*(s: Stream; n: float) =
  ## Creates a new `JFloat JsonNode`.
  s.write formatFloat(n)

proc jsonFrom*(s: Stream; b: bool) =
  ## Creates a new `JBool JsonNode`.
  s.write if b: "true" else: "false"

proc jsonFrom*[T](s: Stream; elements: openArray[T]) =
  ## Generic constructor for JSON data. Creates a new `JArray JsonNode`
  var comma = false
  s.write "["
  for elem in elements:
    if comma: s.write ","
    else: comma = true
    jsonFrom(s, elem)
  s.write "]"

proc jsonFrom*(s: Stream; o: object) =
  ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
  var comma = false
  s.write "{"
  for k, v in o.fieldPairs:
    if comma: s.write ","
    else: comma = true
    escapeJson(s, k)
    s.write ":"
    jsonFrom(s, v)
  s.write "}"

proc jsonFrom*(s: Stream; o: ref object) =
  ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
  if o.isNil:
    s.newJNull()
  else:
    jsonFrom(s, o[])

proc jsonFrom*(s: Stream; o: enum) =
  ## Construct a JsonNode that represents the specified enum value as a
  ## string. Creates a new ``JString JsonNode``.
  jsonFrom(s, $o)

proc jsonFrom*[T](s: Stream; o: SomeSet[T]) =
  var comma = false
  s.write "["
  for elem in o.items:
    if comma: s.write ","
    else: comma = true
    jsonFrom(s, elem)
  s.write "]"

proc jsonFrom*[T](s: Stream; o: (Table[string, T]|OrderedTable[string, T])) =
  var comma = false
  s.write "{"
  for k, v in o.pairs:
    if comma: s.write ","
    else: comma = true
    escapeJson(s, k)
    s.write ":"
    jsonFrom(s, v)
  s.write "}"

proc jsonFrom*[T](s: Stream; o: Option[T]) =
  if isSome(o):
    jsonFrom(s, get(o))
  else:
    s.newJNull()
