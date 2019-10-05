import macros, parsejson, streams, strutils

template loadObj(parser, key, body) =
   eat(parser, tkCurlyLe)
   while parser.tok != tkCurlyRi:
      if parser.tok != tkString:
         raiseParseErr(parser, "string literal as key")
      let key = move(parser.a)
      discard getTok(parser)
      eat(parser, tkColon)
      body
      if parser.tok != tkComma: break
      discard getTok(parser)
   eat(parser, tkCurlyRi)

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
   if parser.tok in {tkInt, tkFloat, tkString}:
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
   else:
      raiseParseErr(parser, "float")

template raiseWrongKey(parser) =
   raiseParseErr(parser, "valid object field")

proc loadAny(nodeTy, param, parser: NimNode): NimNode =
   let baseTy = getTypeImpl(nodeTy)
   case baseTy.typeKind
   of ntyObject:
      let key = genSym(nskLet, "key")
      let caseStr = nnkCaseStmt.newTree(key)
      for n in baseTy[2]:
         n.expectKind nnkIdentDefs
         caseStr.add nnkOfBranch.newTree(newLit(n[0].strVal),
            loadAny(n[1], nnkDotExpr.newTree(param, n[0]), parser))
      caseStr.add nnkElse.newTree(getAst(raiseWrongKey(parser)))
      result = getAst(loadObj(parser, key, caseStr))
   of ntySet, ntySequence:
      let temp = genSym(nskTemp)
      let initTemp = nnkVarSection.newTree(newIdentDefs(temp, baseTy[1]))
      let body = loadAny(baseTy[1], temp, parser)
      let addTemp = newCall(
         if baseTy.typeKind == ntySet: bindSym"incl" else: bindSym"add", param, temp)
      result = getAst(loadSeq(parser, newStmtList(initTemp, body, addTemp)))
   of ntyArray:
      let idx = genSym(nskVar, "i")
      let body = loadAny(baseTy[2], nnkBracketExpr.newTree(param, idx), parser)
      result = getAst(loadArray(parser, param, idx, body))
   of ntyRange:
      result = loadAny(baseTy[1][1], param, parser)
   of ntyDistinct:
      result = newCall(nodeTy, loadAny(baseTy[0], param, parser))
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

template genPackProc(name, retTy, parser, body: untyped): untyped =
   proc name(s: Stream): retTy =
      var parser: JsonParser
      open(parser, s, "unknown file")
      discard getTok(parser)
      body
      eat(parser, tkEof)
      close(parser)

macro to(s: Stream, T: typedesc): untyped =
   let typeSym = getTypeImpl(T)[1]
   let name = genSym(nskProc, "pack")
   let parser = genSym(nskVar, "p")
   let res = ident("result")
   let body = loadAny(typeSym, res, parser)
   result = nnkStmtListExpr.newTree(
      getAst(genPackProc(name, typeSym, parser, body)),
      newCall(name, s))

when isMainModule:
   type Foo = object
      value: int
   let s = newStringStream("{\"value\": 1}")
   let a = s.to(Foo)
   echo a
