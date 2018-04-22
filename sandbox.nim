import macros

dumpAstGen:
  type
    Hoge[T: int; U: not int; V] = object
    RefHoge[T: int; U: not int; V] = ref Hoge[T, U, V]

  proc Hoge(arg: x)[T]: Hoge =
    discard

