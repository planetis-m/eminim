import macros, parsejson, streams, strutils, tables

template loadObj(parser, body) =
   eat(parser, tkCurlyLe)
   while parser.tok != tkCurlyRi:
      if parser.tok != tkString:
         raiseParseErr(parser, "string literal as key")
      body
      if parser.tok != tkComma: break
      discard getTok(parser)
   eat(parser, tkCurlyRi)

template getFieldValue(parser) =
   discard getTok(parser)
   eat(parser, tkColon)

template raiseWrongKey(parser) =
   raiseParseErr(parser, "valid object field")

template loadSeq(parser, body) =
   eat(parser, tkBracketLe)
   while parser.tok != tkBracketRi:
      body
      if parser.tok != tkComma: break
      discard getTok(parser)
   eat(parser, tkBracketRi)

template loadArray(parser, data, idx, body) =
   eat(parser, tkBracketLe)
   var idx = 0
   while parser.tok != tkBracketRi:
      body
      inc(idx)
      if parser.tok != tkComma: break
      discard getTok(parser)
   assert idx == len(data)
   eat(parser, tkBracketRi)

template loadString(parser, data) =
   if parser.tok == tkNull:
      data = ""
      discard getTok(parser)
   elif parser.tok == tkString:
      data = move(parser.a)
      discard getTok(parser)
   else:
      raiseParseErr(parser, "string, int or float")

template loadChar(parser, data) =
   if parser.tok == tkString and len(parser.a) == 1:
      data = parser.a[0]
      discard getTok(parser)
   elif parser.tok == tkInt:
      data = char(parseInt(parser.a))
      discard getTok(parser)
   else:
      raiseParseErr(parser, "string of length 1 or int for a char")

template loadBool(parser, data) =
   case parser.tok
   of tkTrue:
      data = true
      discard getTok(parser)
   of tkFalse:
      data = false
      discard getTok(parser)
   else:
      raiseParseErr(parser, "'true' or 'false' for a bool")

template loadEnum(parser, data, dataTy) =
   if parser.tok == tkString:
      data = parseEnum[dataTy](parser.a)
      discard getTok(parser)
   elif parser.tok == tkInt:
      data = dataTy(parseInt(parser.a))
      discard getTok(parser)
   else:
      raiseParseErr(parser, "string or int for a enum")

template loadInt(parser, data, dataTy) =
   if parser.tok == tkInt:
      data = dataTy(parseInt(parser.a))
      discard getTok(parser)
   else:
      raiseParseErr(parser, "int")

template loadFloat(parser, data, dataTy) =
   if parser.tok == tkFloat:
      data = dataTy(parseFloat(parser.a))
      discard getTok(parser)
   elif parser.tok == tkInt:
      data = dataTy(parseInt(parser.a))
      discard getTok(parser)
   else:
      raiseParseErr(parser, "float or int")

proc loadAny(nodeTy, param, parser, genProcs: NimNode, cache: TableRef[string,
      NimNode], isRef: bool, depth: int): NimNode =
   if depth > 150:
      error("Recursion limit reached")
   let baseTy = getTypeImpl(nodeTy)
   case baseTy.typeKind
   of ntyRef:
      let key = nodeTy.repr
      if cache.hasKey(key):
         result = newAssignment(param, newCall(cache[key], parser))
      else:
         let res = ident"result"
         let parserPar = genSym(nskParam, "p")
         let name = genSym(nskProc, "pack")
         cache[nodeTy.repr] = name
         genProcs.add newProc(name, [nodeTy, newIdentDefs(parserPar,
               nnkVarTy.newTree(bindSym"JsonParser"))],
            newStmtList(newCall(bindSym"new", res), loadAny(baseTy[0], res,
                  parserPar, genProcs, cache, true, depth + 1)),
            pragmas = nnkPragma.newTree(ident"nimcall"))
         result = newAssignment(param, newCall(name, parser))
   of ntyObject, ntyTuple:
      if baseTy.kind == nnkTupleConstr:
         error("Use a named tuple instead of: " & nodeTy.repr)
      let key = nodeTy.repr
      if cache.hasKey(key):
         result = newAssignment(param, newCall(cache[key], parser))
      else:
         let parser2 = if isRef: parser else: genSym(nskParam, "p")
         let res = ident"result"
         let caseStr = nnkCaseStmt.newTree(newDotExpr(parser2, ident"a"))
         let idents = if baseTy.kind == nnkTupleTy: baseTy else: baseTy[2]
         for n in idents:
            n.expectKind nnkIdentDefs
            caseStr.add nnkOfBranch.newTree(newLit(n[0].strVal),
               newStmtList(getAst(getFieldValue(parser2)),
                  loadAny(n[1], newDotExpr(res, n[0]), parser2, genProcs, cache,
                        false, depth + 1)))
         caseStr.add nnkElse.newTree(getAst(raiseWrongKey(parser2)))
         if isRef:
            result = newStmtList(getAst(loadObj(parser2, caseStr)))
         else:
            let name = genSym(nskProc, "pack")
            cache[nodeTy.repr] = name
            genProcs.add newProc(name,
               [nodeTy, newIdentDefs(parser2, nnkVarTy.newTree(
                     bindSym"JsonParser"))],
               getAst(loadObj(parser2, caseStr)), pragmas = nnkPragma.newTree(
                     ident"nimcall"))
            result = newAssignment(param, newCall(name, parser))
   of ntySet, ntySequence:
      let temp = genSym(nskTemp)
      let initTemp = nnkVarSection.newTree(newIdentDefs(temp, baseTy[1]))
      let body = loadAny(baseTy[1], temp, parser, genProcs, cache, false,
            depth + 1)
      let addTemp = newCall(
         if baseTy.typeKind == ntySet: bindSym"incl" else: bindSym"add", param, temp)
      result = getAst(loadSeq(parser, newStmtList(initTemp, body, addTemp)))
   of ntyArray:
      let idx = genSym(nskVar, "i")
      let body = loadAny(baseTy[2], nnkBracketExpr.newTree(param, idx), parser,
            genProcs, cache, false, depth + 1)
      result = getAst(loadArray(parser, param, idx, body))
   of ntyRange:
      result = loadAny(baseTy[1][1], param, parser, genProcs, cache, false,
            depth + 1)
   of ntyDistinct:
      result = loadAny(baseTy[0], param, parser, genProcs, cache, false, depth + 1)
   of ntyString:
      result = getAst(loadString(parser, param))
   of ntyChar:
      result = getAst(loadChar(parser, param))
   of ntyBool:
      result = getAst(loadBool(parser, param))
   of ntyEnum:
      result = getAst(loadEnum(parser, param, nodeTy))
   of ntyInt..ntyInt64, ntyUInt..ntyUInt64:
      result = getAst(loadInt(parser, param, baseTy))
   of ntyFloat..ntyFloat64:
      result = getAst(loadFloat(parser, param, baseTy))
   else:
      error("Unsupported type: " & nodeTy.repr)

template genPackProc(parser, retTy, name, body: untyped): untyped =
   proc name(s: Stream): retTy =
      var parser: JsonParser
      open(parser, s, "unknown file")
      try:
         discard getTok(parser)
         body
         eat(parser, tkEof)
      finally:
         close(parser)

macro to*(s: Stream, T: typedesc): untyped =
   let typeSym = getTypeImpl(T)[1]
   let name = genSym(nskProc, "pack")
   let parser = genSym(nskVar, "p")
   let res = ident"result"
   let genProcs = newStmtList()
   let cache = newTable[string, NimNode]()
   let body = newStmtList(genProcs, loadAny(typeSym, res, parser, genProcs,
         cache, false, 0))
   result = nnkStmtListExpr.newTree(
      getAst(genPackProc(parser, typeSym, name, body)),
      newCall(name, s))

when isMainModule:
   # TODO:
   # - fix distinct
   # - support object variants
   # - correctly compare nim identifiers
   # - add Tables, OrderedTables
   type
      Foo = ref object
         value: int
   let s = newStringStream("{\"value\": 1}")
   let a = s.to(Foo)
