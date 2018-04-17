import macros
import sequtils
import strutils
import tables

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

  for node in body:
    if node.kind == nnkIdent:
      kinds.add(node.ident)
      typeIdsSeq.add(nnkTupleTy.newTree())
    elif node.kind == nnkInfix:
      if node[0].ident != !"of" or node[1].kind != nnkIdent:
        error "a Kind is Invalid:\n" & body.treeRepr
      kinds.add(node[1].ident)
      typeIdsSeq.add(node[2])
    else:
      error "a cloud is Invalid:\n"

  for x in kinds:
    kindToType[$x] = name

  # Define [TypeName]Kind
  let
    kindName = name & "Kind"
    objName = name & "Obj"
    kindIdentNodes = kinds.map(newIdentNode)
    kindNodes = nnkEnumTy.newTree(
      concat(@[newEmptyNode()], kindIdentNodes))
  var kindTree = nnkTypeDef.newTree(
    (kindName).newDecIdentNode(public),
    newEmptyNode(),
    kindNodes
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

  result = nnkStmtList.newTree(
    nnkTypeSection.newTree(
      kindTree,
      tyTree,
      tyObjTree,
    )
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
        cloud[0],
        nnkStmtList.newTree(cloudBody)
      )
    )

  result = nnkStmtList.newTree(
    nnkCaseStmt.newTree(
      matchClouds
    )
  )

macro new*(kind: untyped, args: varargs[untyped]): untyped =
  var kindname: string
  if kind.kind == nnkSym:
    kindname = $kind.symbol
  elif kind.kind == nnkIdent:
    kindname = $kind.ident
  else:
    error "new requires nnkSym or nnkIdent as the first arg.:\n" & kind.treeRepr

  result = nnkStmtList.newTree(
    nnkObjConstr.newTree(
      newIdentNode(kindToType[kindname]),
      nnkExprColonExpr.newTree(
        newIdentNode("kind"),
        newIdentNode(kindname)
      ),
      nnkExprColonExpr.newTree(
        newIdentNode(kindname.kindToValName),
        nnkPar.newTree(
          args.toSeq
        )
      )
    )
  )
