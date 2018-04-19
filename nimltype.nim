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

var kindToType {.compiletime.}: TableRef[string, string] =
  newTable[string, string]()

proc kindToValName(kind: string): string {.compiletime.} =
  return toLower(kind) & "Val"

proc kindToValName(kind: NimIdent): string {.compiletime.} =
  return ($kind).kindToValName

macro nimltype*(id, body: untyped): untyped =
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

  var
    name: string
    public: bool

  if id.kind == nnkPrefix and id[0].ident == !"*":
    public = true
    name = $id[1].ident
  elif id.kind == nnkIdent:
    public = false
    name = $id.ident
  else:
    error "IdNode is Invalid:\n" & id.treeRepr

  if body.kind != nnkStmtList:
    error "BodyNode is Invalid:\n" & body.treeRepr

  var
    kinds: seq[NimIdent] = @[]
    typeIdsSeq: seq[NimNode] = @[]
    kindNodes: seq[NimNode] = @[newEmptyNode()]

  for node in body:
    if node.kind == nnkIdent:
      kinds.add(node.ident)
      kindNodes.add(node)
      typeIdsSeq.add(nnkTupleTy.newTree())
    elif node.kind == nnkInfix:
      if node[0].ident != !"of" or node[1].kind != nnkIdent:
        error "a Kind is Invalid:\n" & body.treeRepr
      kinds.add(node[1].ident)
      kindNodes.add(node[1])
      typeIdsSeq.add(node[2])
    elif node.kind == nnkAsgn:
      kinds.add(node[0].ident)
      if node[1].kind == nnkInfix:
        if node[1][0].ident != !"of":
          error "a Kind is Invalid:\n" & body.treeRepr
        typeIdsSeq.add(node[1][2])
        kindNodes.add(
          nnkEnumFieldDef.newTree(
            node[0],
            node[1][1]
          )
        )
      elif node.len == 2:
        typeIdsSeq.add(nnkTupleTy.newTree())
        kindNodes.add(
          nnkEnumFieldDef.newTree(
            node[0],
            node[1]
          )
        )
      else:
        error "a cloud is Invalid:\n" & body.treeRepr
    else:
      error "a cloud is Invalid:\n" & body.treeRepr

    assert kinds.len == kindNodes.len - 1
    assert kinds.len == typeIdsSeq.len

  for x in kinds:
    kindToType[$x] = name

  # Define [TypeName]Kind
  let
    kindName = name & "Kind"
    objName = name & "Obj"
  var kindTree = nnkTypeDef.newTree(
    nnkPragmaExpr.newTree(
      (kindName).newDecIdentNode(public),
      nnkPragma.newTree(
        newIdentNode("pure")
      )
    ),
    newEmptyNode(),
    nnkEnumTy.newTree(
      kindNodes
    )
  )

  # Define [TypeName]
  var tyTree = nnkTypeDef.newTree(
    name.newDecIdentNode(public),
    newEmptyNode(),
    nnkRefTy.newTree(
      newIdentNode(objName)
    )
  )

  # Define [TypeName]Obj
  var
    caseTree: seq[NimNode] = @[nnkIdentDefs.newTree(
      "kind".newDecIdentNode(public),
      newIdentNode(kindName),
      newEmptyNode()
    )]

  for kindAndTypeIds in zip(kinds, typeIdsSeq):
    let (kind, typeIds) = kindAndTypeIds
    caseTree.add(
      nnkOfBranch.newTree(
        newIdentNode(kind),
        nnkRecList.newTree(
          nnkIdentDefs.newTree(
            kind.kindToValName.newDecIdentNode(public),
            typeIds,
            newEmptyNode()
          )
        )
      )
    )

  var tyObjTree = nnkTypeDef.newTree(
    newIdentNode(objName),
    newEmptyNode(),
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

  # Define constructor procs
  var constructorProcs: seq[NimNode] = @[]
  for kindAndTypeIds in zip(kinds, typeIdsSeq):
    let (kind, typeIds) = kindAndTypeIds
    var
      args: seq[NimNode] = @[]
      argnames: seq[NimNode] = @[]
      valNode: NimNode
    if typeIds.kind == nnkPar:
      for i, typeId in typeIds:
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
    elif typeIds.kind == nnkIdent:
      args.add(
        nnkIdentDefs.newTree(
          newIdentNode("arg"),
          typeIds,
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
    constructorProcs.add(
      nnkProcDef.newTree(
        kind.newDecIdentNode(public),
        newEmptyNode(),
        newEmptyNode(),
        nnkFormalParams.newTree(
          concat(
            @[newIdentNode(kindToType[$kind])],
            args
          )
        ),
        newEmptyNode(),
        newEmptyNode(),
        nnkStmtList.newTree(
          nnkReturnStmt.newTree(
            nnkObjConstr.newTree(
              newIdentNode(kindToType[$kind]),
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
    )

  # Define toString proc
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
  let toStringProc: NimNode = nnkProcDef.newTree(
    "$".newDecAccQuotedIdent(public),
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      newIdentNode("string"),
      nnkIdentDefs.newTree(
        newIdentNode("x"),
        newIdentNode(name),
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

  var resultSeq: seq[NimNode] = @[]
  resultSeq.add(
    nnkTypeSection.newTree(
      kindTree,
      tyTree,
      tyObjTree,
    )
  )
  resultSeq = concat(resultSeq, constructorProcs)
  resultSeq.add(toStringProc)
  result = nnkStmtList.newTree(
    resultSeq
  )

macro match*(head, body: untyped): untyped =
  if head.kind != nnkIdent:
    error "match's arg is Invalid:\n" & head.treeRepr

  if body.kind != nnkStmtList:
    error "match's body is Invalid:\n" & body.treeRepr

  var matchClouds: seq[NimNode] = @[
          nnkDotExpr.newTree(
        head,
        newIdentNode("kind")
      )
    ]

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

    cloudBody.add(cloud[^1])
    matchClouds.add(
      nnkOfBranch.newTree(
        nnkDotExpr.newTree(
          newIdentNode(kindToType[$cloud[0].ident] & "Kind"),
          cloud[0]
        ),
        nnkStmtList.newTree(cloudBody)
      )
    )

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
    nnkObjConstr.newTree(
      newIdentNode(kindToType[kindName]),
      nnkExprColonExpr.newTree(
        newIdentNode("kind"),
        nnkDotExpr.newTree(
          newIdentNode(kindToType[kindName] & "Kind"),
          newIdentNode(kindname)
        )
      ),
      nnkExprColonExpr.newTree(
        newIdentNode(kindName.kindToValName),
        nnkPar.newTree(
          args.toSeq
        )
      )
    )
  )
