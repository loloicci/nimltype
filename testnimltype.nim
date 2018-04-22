import nimltype

nimltype *Hoge:
  HA of int
  HB of (int, int)
  HC
  HD of string
  HE of (int, string)

nimltype Fuga:
  FA = "a" of int
  FB = "b" of (int, int)
  FC = "c"
  FD = "d" of string
  FE = "e" of (int, string)

nimltype *Piyo[T1, T2: int | string, T3: not int]:
  PA of (T1)
  PB of (T1, T2)
  PC
  PD of T3
  PE of (T1, T3)

proc testMatch(x: Hoge): bool =
  match x:
    HA a:
      return a == 3
    HB (a, b):
      return a == 2 and b == 3
    HC:
      return true
    HD a:
      return a == "hoge"
    HE (_, b):
      if b == "fuga":
         result = true

proc testMatch(x: Fuga): bool =
  match x:
    FA a:
      return a == 3
    FB (a, b):
      return a == 2 and b == 3
    FC:
      return true
    FD a:
      return a == "hoge"
    FE (_, b):
      if b == "fuga":
         result = true

proc testMatch[T1; T2: int | string; T3: not int](x: Piyo[T1, T2, T3]): bool =
  match x:
    PA a:
      return a == 3
    PB (a, b):
      return a == 2 and b == 3
    PC:
      return true
    PD a:
      return a == "hoge"
    PE (_, b):
      if b == "fuga":
         result = true

let
  ha = HA(3)
  hb = HB(2, 3)
  hc = HC()
  hd = HD("hoge")
  he = HE(2, "fuga")

let
  fa = FA.new(3)
  fb = FB.new(2, 3)
  fc = FC.new
  fd = FD.new("hoge")
  fe = FE.new(2, "fuga")

let
  pa = PA[int, int, string](3)
  pb = PB[int, int, string](2, 3)
  pc = PC[int, int, string]()
  pd = PD[int, int, string]("hoge")
  pe = PE[int, int, string](2, "fuga")

#[
let
  paa = P.PA.new(3)
  pbb = P.PB.new(2, 3)
  pcc = P.PC.new
  pdd = P.PD.new("hoge")
  pee = P.PE.new(2, "fuga")
]#

doAssert testMatch ha
doAssert testMatch hb
doAssert testMatch hc
doAssert testMatch hd
doAssert testMatch he

doAssert testMatch fa
doAssert testMatch fb
doAssert testMatch fc
doAssert testMatch fd
doAssert testMatch fe

doAssert testMatch pa
doAssert testMatch pb
doAssert testMatch pc
doAssert testMatch pd
doAssert testMatch pe

doAssert $ha == "HA(3)"
doAssert $hb == "HB(2, 3)"
doAssert $hc == "HC"
doAssert $hd == "HD(hoge)"
doAssert $he == "HE(2, fuga)"

doAssert $fa == "a(3)"
doAssert $fb == "b(2, 3)"
doAssert $fc == "c"
doAssert $fd == "d(hoge)"
doAssert $fe == "e(2, fuga)"

doAssert $pa == "PA(3)"
doAssert $pb == "PB(2, 3)"
doAssert $pc == "PC"
doAssert $pd == "PD(hoge)"
doAssert $pe == "PE(2, fuga)"

echo "Succeed"
