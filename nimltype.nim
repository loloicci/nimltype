import macros
import sequtils
import strutils
import tables

proc nimlValueToString*(x: tuple): string =
  result = ""
  var i = 0
  for n in x.fields:
    if i == 0:
      result = result & "("
    else:
      result = result & ", "
    result = result & $n
    inc i
  if i > 0:
    result = result & ")"

proc nimlValueToString*[T: not tuple](x: T): string =
  return "(" & $x & ")"

var
  kindToType {.compiletime.}: TableRef[string, string] =
    newTable[string, string]()
  constructorToArgs {.compiletime.}: TableRef[string, seq[NimNode]] =
    newTable[string, seq[NimNode]]()
  typeToConstructors {.compiletime.}: TableRef[string, seq[NimIdent]] =
    newTable[string, seq[NimIdent]]()
  typeToGeneric {.compiletime.}: TableRef[string, NimNode] =
    newTable[string, NimNode]()

proc kindToValName(kind: string): string =
  return strutils.toLowerAscii(kind) & "Val"

proc kindToValName(kind: NimIdent): string {.compiletime.} =
  return ($kind).kindToValName

proc newDecIdentNode(name: NimIdent, isPublic: bool): NimNode =
  if isPublic:
    result = nnkPostfix.newTree(
      newIdentNode("*"),
      newIdentNode(name)
    )
  else:
    result = newIdentNode(name)

proc newDecIdentNode(name: string, isPublic: bool): NimNode =
  return newDecIdentNode(!name, isPublic)

#[
proc newDecAccQuotedIdent(name: string, isPublic: bool): NimNode =
  if isPublic:
    result = nnkPostfix.newTree(
      newIdentNode("*"),
      nnkAccQuoted.newTree(
        newIdentNode(name)
      )
    )
  else:
    result = nnkAccQuoted.newTree(
      newIdentNode(name)
    )
]#

proc parseBracket(b: NimNode): tuple[name: string, bracket: seq[NimNode]] =
  if b.kind == nnkIdent:
    result.name = $b.ident
    result.bracket = @[]
  elif b.kind == nnkBracketExpr:
    result.bracket = @[]
    for i, n in b:
      if i == 0:
        result.name = $n.ident
      else:
        result.bracket.add(n)
  else:
    error "Bracket is Invalid:\n" & b.treeRepr

proc parseHeaderIdent(hi: NimNode): tuple[name: string, tyGeneric: NimNode] =
  if hi.kind == nnkIdent:
    result.name = $hi.ident
    result.tyGeneric = newEmptyNode()
  elif hi.kind == nnkBracketExpr:
    var genericTree: seq[NimNode] = @[]
    for i, n in hi:
      if i == 0:
        result.name = $n.ident
      else:
        if n.kind == nnkExprColonExpr:
          genericTree.add(
            nnkIdentDefs.newTree(
              n[0],
              n[1],
              newEmptyNode()
            )
          )
        elif n.kind == nnkIdent:
          genericTree.add(
            nnkIdentDefs.newTree(
              n,
              newEmptyNode(),
              newEmptyNode()
            )
          )
        else:
          error "Nimltype's Head is Invalid:\n" & hi.treeRepr
    result.tyGeneric = nnkGenericParams.newTree(
      genericTree
    )
  else:
    error "Nimltype's Head is Invalid:\n" & hi.treeRepr


proc parseHeader(head: NimNode): tuple[public: bool, name: string,
                                       tyGeneric: NimNode] =
  if head.kind == nnkPrefix and head[0].ident == !"*":
    result.public = true
    (result.name, result.tyGeneric) = parseHeaderIdent(head[1])
  else:
    result.public = false
    (result.name, result.tyGeneric) = parseHeaderIdent(head)

proc parseBodyCloud(cloud: NimNode): tuple[
    kind: NimIdent, kindNode: NimNode, typeId: NimNode] =
  if cloud.kind == nnkIdent:
    result.kind = cloud.ident
    result.kindNode = cloud
    result.typeId = nnkTupleTy.newTree()
  elif cloud.kind == nnkInfix:
    if cloud[0].ident != !"of" or cloud[1].kind != nnkIdent:
      error "a Kind is Invalid:\n" & cloud.treeRepr
    result.kind = cloud[1].ident
    result.kindNode = cloud[1]
    result.typeId = cloud[2]
  elif cloud.kind == nnkAsgn:
    result.kind = cloud[0].ident
    if cloud[1].kind == nnkInfix:
      if cloud[1][0].ident != !"of":
        error "a Kind is Invalid:\n" & cloud.treeRepr
      result.typeId = cloud[1][2]
      result.kindNode = nnkEnumFieldDef.newTree(
        cloud[0],
        cloud[1][1]
      )
    elif cloud.len == 2:
      result.typeId = nnkTupleTy.newTree()
      result.kindNode = nnkEnumFieldDef.newTree(
        cloud[0],
        cloud[1]
      )
    else:
      error "a cloud is Invalid:\n" & cloud.treeRepr
  else:
    error "a cloud is Invalid:\n" & cloud.treeRepr

proc newBracketOfRefObjectWithGeneric(
    nimltypeName: string, tyGeneric: NimNode): NimNode =
  if tyGeneric.kind == nnkGenericParams:
    var bracketItems: seq[NimNode] = @[newIdentNode(nimltypeName)]
    for i, x in tyGeneric:
      bracketItems.add(x[0])
    result = nnkBracketExpr.newTree(bracketItems)
  elif tyGeneric.kind == nnkEmpty:
    result = newIdentNode(nimltypeName)
  else:
    error "tyGeneric is Invalid:\n" & tyGeneric.treeRepr

proc newPureEnumTree(
    name: string, ofClouds: seq[NimNode], public: bool): NimNode =
  result = nnkTypeDef.newTree(
    nnkPragmaExpr.newTree(
      name.newDecIdentNode(public),
      nnkPragma.newTree(
        newIdentNode("pure")
      )
    ),
    newEmptyNode(),
    nnkEnumTy.newTree(
      concat(@[newEmptyNode()], ofClouds)
    )
  )

proc newRefObjectTree(
    name: string, refTarget: string, tyGeneric: NimNode,
    public: bool): NimNode =
  let refTyTree = newBracketOfRefObjectWithGeneric(refTarget, tyGeneric)
  result = nnkTypeDef.newTree(
    name.newDecIdentNode(public),
    tyGeneric,
    nnkRefTy.newTree(
      refTyTree
    )
  )

proc newNimltypeTree(
    name, kindName: string, tyGeneric: NimNode,
    kinds: seq[NimIdent], typeIdsNodes: seq[NimNode], public: bool): NimNode =
  var
    caseTree: seq[NimNode] = @[nnkIdentDefs.newTree(
      "kind".newDecIdentNode(public),
      newIdentNode(kindName),
      newEmptyNode()
    )]

  for kindAndTypeIds in zip(kinds, typeIdsNodes):
    let (kind, typeIdsNode) = kindAndTypeIds
    caseTree.add(
      nnkOfBranch.newTree(
        newIdentNode(kind),
        nnkRecList.newTree(
          nnkIdentDefs.newTree(
            kind.kindToValName.newDecIdentNode(public),
            typeIdsNode,
            newEmptyNode()
          )
        )
      )
    )

  result = nnkTypeDef.newTree(
    newIdentNode(name),
    tyGeneric,
    nnkObjectTy.newTree(
      newEmptyNode(),
      newEmptyNode(),
      nnkRecList.newTree(
        nnkRecCase.newTree(
          caseTree
        )
      )
    )
  )

proc newConstructorProcTree(
    kind: NimIdent, kindName: string, tyGeneric: NimNode,
    typeIdsNode: NimNode, public: bool): NimNode =
  var
    args: seq[NimNode] = @[]
    argnames: seq[NimNode] = @[]
    valNode: NimNode
  if typeIdsNode.kind == nnkPar:
    for i, typeId in typeIdsNode:
      args.add(
        nnkIdentDefs.newTree(
          newIdentNode("arg" & $i),
          typeId,
          newEmptyNode()
        )
      )
      argnames.add(
        newIdentNode("arg" & $i)
      )
  elif typeIdsNode.kind == nnkIdent:
    args.add(
      nnkIdentDefs.newTree(
        newIdentNode("arg"),
        typeIdsNode,
        newEmptyNode()
      )
    )
    argnames.add(
      newIdentNode("arg")
    )
  if argnames.len == 1:
    valNode = argnames[0]
  else:
    valNode = nnkPar.newTree(
      argnames
    )

  constructorToArgs[$kind] = args

  result = nnkProcDef.newTree(
    kind.newDecIdentNode(public),
    newEmptyNode(),
    tyGeneric,
    nnkFormalParams.newTree(
      concat(
        @[newBracketOfRefObjectWithGeneric(kindToType[$kind], tyGeneric)],
        args
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      nnkReturnStmt.newTree(
        nnkObjConstr.newTree(
          newBracketOfRefObjectWithGeneric(kindToType[$kind], tyGeneric),
          nnkExprColonExpr.newTree(
            newIdentNode("kind"),
            nnkDotExpr.newTree(
              newIdentNode(kindName),
              newIdentNode(kind)
            )
          ),
        nnkExprColonExpr.newTree(
          newIdentNode(kind.kindToValName),
          valNode
        )
        )
      )
    )
  )

#[
proc newNimltypeToStringProc(
    nimltypeName: string, kindName: string, tyGeneric: NimNode,
    kinds: seq[NimIdent], public: bool): NimNode =
  var toStringCaseClouds: seq[NimNode] = @[
    nnkDotExpr.newTree(
      newIdentNode("x"),
      newIdentNode("kind")
    )
  ]
  for kind in kinds:
    toStringCaseClouds.add(
      nnkOfBranch.newTree(
        nnkDotExpr.newTree(
          newIdentNode(kindName),
          newIdentNode(kind)
        ),
        nnkStmtList.newTree(
          nnkReturnStmt.newTree(
            nnkInfix.newTree(
              newIdentNode("&"),
              nnkPrefix.newTree(
                newIdentNode("$"),
                nnkDotExpr.newTree(
                  newIdentNode("x"),
                  newIdentNode("kind")
                )
              ),
              nnkCall.newTree(
                newIdentNode("nimlValueToString"),
                nnkDotExpr.newTree(
                  newIdentNode("x"),
                  newIdentNode(kind.kindToValName)
                )
              )
            )
          )
        )
      )
    )

  result = nnkProcDef.newTree(
    "$".newDecAccQuotedIdent(public),
    newEmptyNode(),
    tyGeneric,
    nnkFormalParams.newTree(
      newIdentNode("string"),
      nnkIdentDefs.newTree(
        newIdentNode("x"),
        newBracketOfRefObjectWithGeneric(nimltypeName, tyGeneric),
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      nnkCaseStmt.newTree(
        toStringCaseClouds
      )
    )
  )
]#

macro nimltype*(head, body: untyped): untyped =
  body.expectKind(nnkStmtList)

  let
    (public, name, tyGeneric) = parseHeader(head)
    kindName = name & "Kind"
    objName = name & "Obj"

  var
    kinds: seq[NimIdent] = @[]
    kindNodes: seq[NimNode] = @[]
    typeIdsNodes: seq[NimNode] = @[]


  for cloud in body:
    let (kind, kindNode, typeId) = parseBodyCloud(cloud)
    kinds.add(kind)
    kindNodes.add(kindNode)
    typeIdsNodes.add(typeId)

    # `kindToType` is global var
    kindToType[$kind] = name

  typeToConstructors[name] = kinds
  typeToGeneric[name] = tyGeneric

  # Define [TypeName]Kind
  let kindTree = newPureEnumTree(kindName, kindNodes, public)

  # Define [TypeName]
  let tyTree = newRefObjectTree(name, objName, tyGeneric, public)

  # Define [TypeName]Obj
  let tyObjTree = newNimltypeTree(
    objName, kindName, tyGeneric, kinds, typeIdsNodes, public)

  # Define constructor procs
  var constructorProcs: seq[NimNode] = @[]
  for kindAndTypeIds in zip(kinds, typeIdsNodes):
    let (kind, typeIdsNode) = kindAndTypeIds
    constructorProcs.add(
      newConstructorProcTree(kind, kindName, tyGeneric, typeIdsNode, public)
    )

  # Define toString proc
  # let toStringProc = newNimltypeToStringProc(
  #   name, kindName, tyGeneric, kinds, public)

  # Make result
  var resultSeq: seq[NimNode] = @[]
  resultSeq.add(
    nnkTypeSection.newTree(
      kindTree,
      tyTree,
      tyObjTree,
    )
  )
  resultSeq = concat(resultSeq, constructorProcs)
  # resultSeq.add(toStringProc)
  result = nnkStmtList.newTree(
    resultSeq
  )

macro match*(head, body: untyped): untyped =
  body.expectKind(nnkStmtList)

  var matchClouds: seq[NimNode] = @[
          nnkDotExpr.newTree(
        head,
        newIdentNode("kind")
      )
    ]
  var elseCloud: NimNode = newNilLit()

  for cloud in body:
    var cloudBody: seq[NimNode] = @[]
    if cloud.kind == nnkCommand:
      if cloud[1].kind == nnkIdent:
        cloudBody.add(
          nnkLetSection.newTree(
            nnkIdentDefs.newTree(
              cloud[1],
              newEmptyNode(),
              nnkDotExpr.newTree(
                head,
                cloud[0].ident.kindToValName.newIdentNode
              )
            )
          )
        )
      elif cloud[1].kind == nnkPar:
        var ids: seq[NimNode] = @[]
        for id in cloud[1]:
          id.expectKind(nnkIdent)
          ids.add(id)
        ids.add(newEmptyNode())
        ids.add(
          nnkDotExpr.newTree(
            head,
            cloud[0].ident.kindToValName.newIdentNode
          )
        )
        cloudBody.add(
          nnkLetSection.newTree(
            nnkVarTuple.newTree(
              ids
            )
          )
        )
      else:
         error "cloud is Invalid\n" & cloud.treeRepr
      if cloud.len == 4:
        cloud[3].expectKind(nnkElse)
        cloudBody.add(cloud[2])
        elseCloud = cloud[3]
      elif cloud.len == 3:
        cloudBody.add(cloud[2])
      else:
         error "cloud is Invalid\n" & cloud.treeRepr
    else:
      cloud.expectKind(nnkCall)
      if cloud.len == 3:
        cloud[2].expectKind(nnkElse)
        cloudBody.add(cloud[1])
        elseCloud = cloud[2]
      elif cloud.len == 2:
        cloudBody.add(cloud[1])
      else:
         error "cloud is Invalid\n" & cloud.treeRepr
    matchClouds.add(
      nnkOfBranch.newTree(
        nnkDotExpr.newTree(
          newIdentNode(kindToType[$cloud[0].ident] & "Kind"),
          cloud[0]
        ),
        nnkStmtList.newTree(cloudBody)
      )
    )
  if elseCloud.kind == nnkElse:
    matchClouds.add(elseCloud)

  result = nnkStmtList.newTree(
    nnkCaseStmt.newTree(
      matchClouds
    )
  )

macro new*(kind: untyped, args: varargs[untyped]): untyped =
  var kindName: string
  if kind.kind == nnkSym:
    kindName = $kind.symbol
  elif kind.kind == nnkIdent:
    kindName = $kind.ident
  else:
    error (
      "new requires nnkSym or nnkIdent as the first arg.:\n" & kind.treeRepr
    )
  result = nnkStmtList.newTree(
    nnkCall.newTree(
      concat(
        @[newIdentNode(kindName)],
        args.toSeq
      )
    )
  )

#[
proc getTyBracket(name: string, tyGeneric: NimNode): NimNode =
  if tyGeneric.kind == nnkGenericParams:
    var bracket = @[newIdentNode(name)]
    for n in tyGeneric:
      bracket.add(n[0])
    result = nnkBracketExpr.newTree(bracket)
  else:
    result = newIdentNode(name)
]#

macro nimlSpecial*(body: untyped): untyped =
  var ret: seq[NimNode] = @[]
  for n in body:
    n.expectKind(nnkAsgn)

    let
      (public, name, tyGeneric) = n[0].parseHeader
      # this is insted for `auto` in follow
      # tyBracket = getTyBracket(name, tyGeneric)
      (gName, gBracket) = n[1].parseBracket
    var
      constructors: seq[NimIdent] = @[]
    typeToGeneric[name] = tyGeneric

    # Define Special Type
    ret.add(
      nnkTypeSection.newTree(
        nnkTypeDef.newTree(
          name.newDecIdentNode(public),
          tyGeneric,
          n[1]
        )
      )
    )

    # Define Special Constructors
    for c in typeToConstructors[gName]:
      var args = constructorToArgs[$c]
      let constructor: string = name & "_" & $c
      constructors.add(!constructor)
      var gs: seq[NimNode] = @[]
      var callArgs: seq[NimNode] = @[]
      for i, a in args:
        gs.add(a[1])
        callArgs.add(a[0])
      for i, g in typeToGeneric[gName]:
        let j = gs.find(g[0])
        if j > -1:
          args[j][1] = gBracket[i]

      # Save Compiletime Information
      constructorToArgs[constructor] = args

      ret.add(
        nnkProcDef.newTree(
          constructor.newDecIdentNode(public),
          newEmptyNode(),
          tyGeneric,
          nnkFormalParams.newTree(
            concat(
              @[newIdentNode("auto")],
              args
            )
          ),
          newEmptyNode(),
          newEmptyNode(),
          nnkStmtList.newTree(
            nnkReturnStmt.newTree(
              nnkCall.newTree(
                concat(
                  @[
                    nnkBracketExpr.newTree(
                      concat(
                        @[newIdentNode(c)],
                        gBracket
                      )
                    )
                  ],
                  callArgs
                )
              )
            )
          )
        )
      )
    typeToConstructors[name] = constructors

  result = nnkStmtList.newTree(ret)
