import macros, parsejson, strutils, streams, options, tables, sets

# serialization
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

proc storeJson*(s: Stream; x: string) =
  ## Creates a new `JString JsonNode`.
  escapeJson(s, x)

proc storeJson*(s: Stream; b: bool) =
  ## Creates a new `JBool JsonNode`.
  s.write if b: "true" else: "false"

proc storeJson*(s: Stream; n: BiggestInt) =
  ## Creates a new `JInt JsonNode`.
  s.write $n

proc storeJson*(s: Stream; n: float) =
  ## Creates a new `JFloat JsonNode`.
  s.write $n

proc storeJson*(s: Stream; o: enum) =
  ## Construct a JsonNode that represents the specified enum value as a
  ## string. Creates a new ``JString JsonNode``.
  storeJson(s, $o)

proc storeJson*[T](s: Stream; elements: openArray[T]) =
  ## Generic constructor for JSON data. Creates a new `JArray JsonNode`
  var comma = false
  s.write "["
  for elem in elements:
    if comma: s.write ","
    else: comma = true
    storeJson(s, elem)
  s.write "]"

proc storeJson*[T](s: Stream; o: SomeSet[T]|set[T]) =
  var comma = false
  s.write "["
  for elem in o.items:
    if comma: s.write ","
    else: comma = true
    storeJson(s, elem)
  s.write "]"

proc storeJson*[T](s: Stream; o: (Table[string, T]|OrderedTable[string, T])) =
  var comma = false
  s.write "{"
  for k, v in o.pairs:
    if comma: s.write ","
    else: comma = true
    escapeJson(s, k)
    s.write ":"
    storeJson(s, v)
  s.write "}"

proc storeJson*(s: Stream; o: ref object) =
  ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
  if o.isNil:
    s.newJNull()
  else:
    storeJson(s, o[])

proc storeJson*[T](s: Stream; o: Option[T]) =
  if isSome(o):
    storeJson(s, get(o))
  else:
    s.newJNull()

proc storeJson*(s: Stream; o: object) =
  ## Generic constructor for JSON data. Creates a new `JObject JsonNode`
  var comma = false
  s.write "{"
  for k, v in o.fieldPairs:
    if comma: s.write ","
    else: comma = true
    escapeJson(s, k)
    s.write ":"
    storeJson(s, v)
  s.write "}"

# deserialization
proc initFromJson*(dst: var string; p: var JsonParser) =
  if p.tok == tkNull:
    dst = ""
    discard getTok(p)
  elif p.tok == tkString:
    dst = p.a
    discard getTok(p)
  else:
    raiseParseErr(p, "string or null")

proc initFromJson*(dst: var char; p: var JsonParser) =
  if p.tok == tkString and len(p.a) == 1:
    dst = p.a[0]
    discard getTok(p)
  elif p.tok == tkInt:
    dst = char(parseInt(p.a))
    discard getTok(p)
  else:
    raiseParseErr(p, "string of length 1 or int for a char")

proc initFromJson*(dst: var bool; p: var JsonParser) =
  case p.tok
  of tkTrue:
    dst = true
    discard getTok(p)
  of tkFalse:
    dst = false
    discard getTok(p)
  else:
    raiseParseErr(p, "'true' or 'false' for a bool")

proc initFromJson*[T: SomeInteger](dst: var T; p: var JsonParser) =
  if p.tok == tkInt:
    dst = T(parseInt(p.a))
    discard getTok(p)
  else:
    raiseParseErr(p, "int")

proc initFromJson*[T: SomeFloat](dst: var T; p: var JsonParser) =
  if p.tok == tkFloat:
    dst = T(parseFloat(p.a))
    discard getTok(p)
  elif p.tok == tkInt:
    dst = T(parseInt(p.a))
    discard getTok(p)
  else:
    raiseParseErr(p, "float or int")

proc initFromJson*[T: enum](dst: var T; p: var JsonParser) =
  if p.tok == tkString:
    dst = parseEnum[T](p.a)
    discard getTok(p)
  elif p.tok == tkInt:
    dst = T(parseInt(p.a))
    discard getTok(p)
  else:
    raiseParseErr(p, "string or int for a enum")

proc initFromJson*[T](dst: var seq[T]; p: var JsonParser) =
  eat(p, tkBracketLe)
  while p.tok != tkBracketRi:
    var tmp: T
    initFromJson(tmp, p)
    dst.add(tmp)
    if p.tok != tkComma: break
    discard getTok(p)
  eat(p, tkBracketRi)

proc initFromJson*[S, T](dst: var array[S, T]; p: var JsonParser) =
  eat(p, tkBracketLe)
  var i: int = low(dst)
  while p.tok != tkBracketRi:
    initFromJson(dst[i], p)
    inc(i)
    if p.tok != tkComma: break
    discard getTok(p)
  if i <= high(dst):
    raise newException(RangeDefect, "array not filled")
  eat(p, tkBracketRi)

proc initFromJson*[T](dst: var set[T]; p: var JsonParser) =
  eat(p, tkBracketLe)
  while p.tok != tkBracketRi:
    var tmp: T
    initFromJson(tmp, p)
    dst.incl(tmp)
    if p.tok != tkComma: break
    discard getTok(p)
  eat(p, tkBracketRi)

proc initFromJson*[T](dst: var (SomeSet[T]|set[T]); p: var JsonParser) =
  eat(p, tkBracketLe)
  while p.tok != tkBracketRi:
    var tmp: T
    initFromJson(tmp, p)
    dst.incl(tmp)
    if p.tok != tkComma: break
    discard getTok(p)
  eat(p, tkBracketRi)

proc initFromJson*[T](dst: var (Table[string, T]|OrderedTable[string, T]); p: var JsonParser) =
  eat(p, tkCurlyLe)
  while p.tok != tkCurlyRi:
    if p.tok != tkString:
      raiseParseErr(p, "string literal as key")
    let key = p.a
    discard getTok(p)
    eat(p, tkColon)
    initFromJson(mgetOrPut(dst, key, default(T)), p)
    if p.tok != tkComma: break
    discard getTok(p)
  eat(p, tkCurlyRi)

proc initFromJson*[T](dst: var ref T; p: var JsonParser) =
  if p.tok == tkNull:
    dst = nil
    discard getTok(p)
  elif p.tok == tkCurlyLe:
    new(dst)
    initFromJson(dst[], p)
  else:
    raiseParseErr(p, "object or null")

proc initFromJson*[T](dst: var Option[T]; p: var JsonParser) =
  if p.tok != tkNull:
    var tmp: T
    initFromJson(tmp, p)
    dst = some(tmp)
  else: none[T]()

proc detectIncompatibleType(typeExpr: NimNode) =
  if typeExpr.kind == nnkTupleConstr:
    error("Use a named tuple instead of: " & typeExpr.repr)

template readFieldsInner(parser, body) =
  if p.tok != tkComma: break
  discard getTok(p)
  while parser.tok != tkCurlyRi:
    if parser.tok != tkString:
      raiseParseErr(parser, "string literal as key")
    body
    if parser.tok != tkComma: break
    discard getTok(parser)

template raiseWrongKey(parser) =
  raiseParseErr(parser, "valid object field")

template getFieldValue(parser, tmpSym, fieldSym) =
  discard getTok(parser)
  eat(parser, tkColon)
  initFromJson(tmpSym.fieldSym, parser)

template getKindValue(parser, tmpSym, kindSym, kindType) =
  discard getTok(parser)
  eat(parser, tkColon)
  var kindTmp: kindType
  initFromJson(kindTmp, parser)
  tmpSym = (typeof tmpSym)(kindSym: kindTmp)

proc foldObjectBody(typeNode, tmpSym, parser: NimNode): NimNode =
  case typeNode.kind
  of nnkEmpty:
    result = newNimNode(nnkNone)
  of nnkRecList, nnkTupleTy:
    result = nnkCaseStmt.newTree(newDotExpr(parser, ident"a"))
    for it in typeNode:
      let x = foldObjectBody(it, tmpSym, parser)
      if x.kind != nnkNone: result.add x
    result.add nnkElse.newTree(getAst(raiseWrongKey(parser)))
  of nnkIdentDefs:
    expectLen(typeNode, 3)
    let fieldSym = typeNode[0]
    let fieldType = typeNode[1]
    detectIncompatibleType(fieldType)
    result = nnkOfBranch.newTree(newLit(fieldSym.strVal),
        getAst(getFieldValue(parser, tmpSym, fieldSym)))
  of nnkRecCase:
    let kindSym = typeNode[0][0]
    let kindType = typeNode[0][1]
    result = nnkOfBranch.newTree(newLit(kindSym.strVal),
        getAst(getKindValue(parser, tmpSym, kindSym, kindType)))
    let inner = nnkCaseStmt.newTree(nnkDotExpr.newTree(tmpSym, kindSym))
    for i in 1..<typeNode.len:
      let x = foldObjectBody(typeNode[i], tmpSym, parser)
      if x.kind != nnkNone: inner.add x
    result[^1].add getAst(readFieldsInner(parser, inner))
  of nnkOfBranch, nnkElse:
    result = copyNimNode(typeNode)
    for i in 0..typeNode.len-2:
      result.add copyNimTree(typeNode[i])
    let inner = newNimNode(nnkStmtListExpr)
    if typeNode[^1].kind == nnkIdentDefs:
      inner.add nnkCaseStmt.newTree(newDotExpr(parser, ident"a"))
    let x = foldObjectBody(typeNode[^1], tmpSym, parser)
    if x.kind == nnkCaseStmt: inner.add x
    elif x.kind != nnkNone: inner[^1].add x
    if typeNode[^1].kind == nnkIdentDefs:
      inner[^1].add nnkElse.newTree(getAst(raiseWrongKey(parser)))
    result.add inner
  of nnkObjectTy:
    expectKind(typeNode[0], nnkEmpty)
    expectKind(typeNode[1], {nnkEmpty, nnkOfInherit})
    result = newNimNode(nnkNone)
    if typeNode[1].kind == nnkOfInherit:
      let base = typeNode[1][0]
      var impl = getTypeImpl(base)
      while impl.kind in {nnkRefTy, nnkPtrTy}:
        impl = getTypeImpl(impl[0])
      result = foldObjectBody(impl, tmpSym, parser)
    let body = typeNode[2]
    let x = foldObjectBody(body, tmpSym, parser)
    if result.kind != nnkNone:
      if x.kind != nnkNone: # merge case statements
        expectKind(result, nnkCaseStmt)
        for i in 1..x.len-2: result.insert(result.len-1, x[i])
    else: result = x
  else:
    error("unhandled kind: " & $typeNode.kind, typeNode)

macro assignObjectImpl(dst: typed; parser: JsonParser): untyped =
  let typeSym = getTypeInst(dst)
  result = newStmtList()
  let x = if typeSym.kind in {nnkTupleTy, nnkTupleConstr}:
    detectIncompatibleType(typeSym)
    foldObjectBody(typeSym, dst, parser)
  else:
    foldObjectBody(typeSym.getTypeImpl, dst, parser)
  if x.kind != nnkNone: result.add x

proc initFromJson*[T: object|tuple](dst: var T; p: var JsonParser) =
  eat(p, tkCurlyLe)
  while p.tok != tkCurlyRi:
    if p.tok != tkString:
      raiseParseErr(p, "string literal as key")
    assignObjectImpl(dst, p)
    if p.tok != tkComma: break
    discard getTok(p)
  eat(p, tkCurlyRi)

proc jsonTo*[T](s: Stream, t: typedesc[T]): T =
  ## Unmarshals the specified node into the object type specified.
  ##
  ## Known limitations:
  ##
  ##   * Heterogeneous arrays are not supported.
  ##   * Sets in object variants are not supported.
  ##   * Not nil annotations are not supported.
  ##
  var p: JsonParser
  open(p, s, "unknown file")
  try:
    discard getTok(p)
    initFromJson(result, p)
    eat(p, tkEof)
  finally:
    close(p)

template whileJsonItems(s, x, xType, body: untyped) =
  # Opens filename and reads an JSON array
  var p: JsonParser
  open(p, s, "unknown file")
  try:
    discard getTok(p)
    eat(p, tkBracketLe)
    while p.tok != tkBracketRi:
      var x: xType
      initFromJson(x, p)
      body
      if p.tok != tkComma: break
      discard getTok(p)
    eat(p, tkBracketRi)
    eat(p, tkEof)
  finally:
    close(p)

macro jsonItems*(x: ForLoopStmt): untyped =
  expectLen(x, 3)
  let iterVar = x[0]
  expectLen(x[1], 3)
  let
    iterType = x[1][2]
    strmVar = x[1][1]
    body = x[^1]
  result = newBlockStmt(getAst(whileJsonItems(strmVar, iterVar, iterType, body)))
