import nimltype

nimltype *Hoge:
  A of int
  B of (int, int)
  C
  D of string
  E of (int, string)

let
  a = A.new(3)
  b = B.new(2, 3)
  c = C.new
  d = D.new("hoge")
  e = E.new(2, "hoge")

proc testMatch(x: Hoge) =
  match x:
    A a:
      echo a
    B (a, b):
      echo a + b
    C:
      echo "C"
    D a:
      echo a
    E (_, _):
      echo "OK"


testMatch a
testMatch b
testMatch c
testMatch d
testMatch e
