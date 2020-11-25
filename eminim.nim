import macros, parsejson, streams, strutils, options, tables

proc initFromJson(dst: var string; p: var JsonParser)
proc initFromJson(dst: var char; p: var JsonParser)
proc initFromJson(dst: var bool; p: var JsonParser)
#proc initFromJson(dst: var JsonNode; p: var JsonParser)
proc initFromJson[T: SomeInteger](dst: var T; p: var JsonParser)
proc initFromJson[T: SomeFloat](dst: var T; p: var JsonParser)
proc initFromJson[T: enum](dst: var T; p: var JsonParser)
proc initFromJson[T](dst: var seq[T]; p: var JsonParser)
proc initFromJson[S, T](dst: var array[S, T]; p: var JsonParser)
proc initFromJson[T](dst: var (Table[string, T]|OrderedTable[string, T]); p: var JsonParser)
proc initFromJson[T](dst: var ref T; p: var JsonParser)
proc initFromJson[T](dst: var Option[T]; p: var JsonParser)
#proc initFromJson[T: distinct](dst: var T; p: var JsonParser)
proc initFromJson[T: object|tuple](dst: var T; p: var JsonParser)

proc initFromJson(dst: var string; p: var JsonParser) =
  if p.tok == tkNull:
    dst = ""
    discard getTok(p)
  elif p.tok == tkString:
    dst = p.a
    discard getTok(p)
  else:
    raiseParseErr(p, "string or null")

proc initFromJson(dst: var char; p: var JsonParser) =
  if p.tok == tkString and len(p.a) == 1:
    dst = p.a[0]
    discard getTok(p)
  elif p.tok == tkInt:
    dst = char(parseInt(p.a))
    discard getTok(p)
  else:
    raiseParseErr(p, "string of length 1 or int for a char")

proc initFromJson(dst: var bool; p: var JsonParser) =
  case p.tok
  of tkTrue:
    dst = true
    discard getTok(p)
  of tkFalse:
    dst = false
    discard getTok(p)
  else:
    raiseParseErr(p, "'true' or 'false' for a bool")

proc initFromJson[T: SomeInteger](dst: var T; p: var JsonParser) =
  if p.tok == tkInt:
    dst = T(parseInt(p.a))
    discard getTok(p)
  else:
    raiseParseErr(p, "int")

proc initFromJson[T: SomeFloat](dst: var T; p: var JsonParser) =
  if p.tok == tkFloat:
    dst = T(parseFloat(p.a))
    discard getTok(p)
  elif p.tok == tkInt:
    dst = T(parseInt(p.a))
    discard getTok(p)
  else:
    raiseParseErr(p, "float or int")

proc initFromJson[T: enum](dst: var T; p: var JsonParser) =
  if p.tok == tkString:
    dst = parseEnum[T](p.a)
    discard getTok(p)
  elif p.tok == tkInt:
    dst = T(parseInt(p.a) + ord(T.low))
    discard getTok(p)
  else:
    raiseParseErr(p, "string or int for a enum")

proc initFromJson[T](dst: var seq[T]; p: var JsonParser) =
  eat(p, tkBracketLe)
  var i = 0
  while p.tok != tkBracketRi:
    var tmp: T
    initFromJson(tmp, p)
    dst.add(tmp)
    inc(i)
    if p.tok != tkComma: break
    discard getTok(p)
  eat(p, tkBracketRi)

proc initFromJson[S, T](dst: var array[S, T]; p: var JsonParser) =
  eat(p, tkBracketLe)
  var i = low(dst)
  while p.tok != tkBracketRi:
    initFromJson(dst[i], p)
    inc(i)
    if p.tok != tkComma: break
    if i > high(dst):
      raise newException(IndexDefect, "index out of bounds")
    discard getTok(p)
  eat(p, tkBracketRi)

proc initFromJson[T](dst: var (Table[string, T]|OrderedTable[string, T]); p: var JsonParser) =
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

proc initFromJson[T](dst: var ref T; p: var JsonParser) =
  if p.tok == tkNull:
    dst = nil
    discard getTok(p)
  elif p.tok == tkCurlyLe:
    dst = new(T)
    initFromJson(dst[], p)
  else:
    raiseParseErr(p, "object or null")

proc initFromJson[T](dst: var Option[T]; p: var JsonParser) =
  if p.tok != tkNull:
    var tmp: T
    initFromJson(tmp, p)
    dst = some(tmp)
  else: none[T]()

proc detectIncompatibleType(typeExpr, lineinfoNode: NimNode) =
  if typeExpr.kind == nnkTupleConstr:
    error("Use a named tuple instead of: " & typeExpr.repr, lineinfoNode)

template loadObj(parser, body) =
  eat(parser, tkCurlyLe)
  while parser.tok != tkCurlyRi:
    if parser.tok != tkString:
      raiseParseErr(parser, "string literal as key")
    body
    if parser.tok != tkComma: break
    discard getTok(parser)
  eat(parser, tkCurlyRi)

template raiseWrongKey(parser) =
  raiseParseErr(parser, "valid object field")

template getFieldValue(parser, tmpSym, fieldSym) =
  discard getTok(parser)
  eat(parser, tkColon)
  initFromJson(tmpSym.fieldSym, parser)

template getKindValue(parser, tmpSym, kindSym, kindType) =
  var kindTmp: kindType
  initFromJson(kindTmp, parser)
  tmpSym.kindSym = kindTmp

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
    # Detecting incompatiple tuple types in `assignObjectImpl` only
    # would be much cleaner, but the ast for tuple types does not
    # contain usable type information.
    detectIncompatibleType(fieldType, fieldSym)
    result = nnkOfBranch.newTree(newLit(fieldSym.strVal),
        getAst(getFieldValue(parser, tmpSym, fieldSym)))
  of nnkRecCase:
    let kindSym = typeNode[0][0]
    let kindType = typeNode[0][1]
    result = getAst(getKindValue(parser, tmpSym, kindSym, kindType))
    result.add nnkCaseStmt.newTree(nnkDotExpr.newTree(tmpSym, kindSym))
    for i in 1..<typeNode.len:
      let x = foldObjectBody(typeNode[i], tmpSym, parser)
      if x.kind != nnkNone: result.add x
  of nnkOfBranch, nnkElse:
    result = copyNimNode(typeNode)
    for i in 0..typeNode.len-2:
      result.add copyNimTree(typeNode[i])
    let inner = newNimNode(nnkStmtListExpr)
    let x = foldObjectBody(typeNode[^1], tmpSym, parser)
    if x.kind != nnkNone: inner.add x
    result.add inner
  of nnkObjectTy:
    expectKind(typeNode[0], nnkEmpty)
    expectKind(typeNode[1], {nnkEmpty, nnkOfInherit})
    result = newStmtList()
    if typeNode[1].kind == nnkOfInherit:
      let base = typeNode[1][0]
      var impl = getTypeImpl(base)
      while impl.kind in {nnkRefTy, nnkPtrTy}:
        impl = getTypeImpl(impl[0])
      result.add foldObjectBody(impl, tmpSym, parser)
    let body = typeNode[2]
    let x = foldObjectBody(body, tmpSym, parser)
    expectKind(x, nnkCaseStmt)
    result.add getAst(loadObj(parser, x))
  else:
    error("unhandled kind: " & $typeNode.kind, typeNode)

macro assignObjectImpl(dst: typed; parser: JsonParser): untyped =
  let typeSym = getTypeInst(dst)
  if typeSym.kind in {nnkTupleTy, nnkTupleConstr}:
    detectIncompatibleType(typeSym, dst)
    result = foldObjectBody(typeSym, dst, parser)
  else:
    result = foldObjectBody(typeSym.getTypeImpl, dst, parser)

proc initFromJson[T: object|tuple](dst: var T; p: var JsonParser) =
  assignObjectImpl(dst, p)

proc jsonTo*[T](s: Stream, t: typedesc[T]): T =
  ## `Unmarshals`:idx: the specified node into the object type specified.
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
