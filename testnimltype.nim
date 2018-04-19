import nimltype

nimltype *Hoge:
  A of int
  B of (int, int)
  C
  D of string
  E of (int, string)

nimltype Fuga:
  AA = "aa" of int
  BB = "bb" of (int, int)
  CC = "cc"
  DD = "dd" of string
  EE = "ee" of (int, string)

proc testMatch(x: Hoge): bool =
  match x:
    A a:
      return a == 3
    B (a, b):
      return a == 2 and b == 3
    C:
      return true
    D a:
      return a == "hoge"
    E (_, _):
      result = true

proc testMatch(x: Fuga): bool =
  match x:
    AA a:
      return a == 3
    BB (a, b):
      return a == 2 and b == 3
    CC:
      return true
    DD a:
      return a == "hoge"
    EE (_, _):
      result = true

let
  aa = AA(3)
  bb = BB(2, 3)
  cc = CC()
  dd = DD("hoge")
  ee = EE(2, "hoge")

let
  a = A.new(3)
  b = B.new(2, 3)
  c = C.new
  d = D.new("hoge")
  e = E.new(2, "hoge")

doAssert testMatch a
doAssert testMatch b
doAssert testMatch c
doAssert testMatch d
doAssert testMatch e

doAssert testMatch aa
doAssert testMatch bb
doAssert testMatch cc
doAssert testMatch dd
doAssert testMatch ee

doAssert $a == "A(3)"
doAssert $b == "B(2, 3)"
doAssert $c == "C"
doAssert $d == "D(hoge)"
doAssert $e == "E(2, hoge)"

doAssert $aa == "aa(3)"
doAssert $bb == "bb(2, 3)"
doAssert $cc == "cc"
doAssert $dd == "dd(hoge)"
doAssert $ee == "ee(2, hoge)"
