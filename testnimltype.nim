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
  PA of T1
  PB of (T1, T2)
  PC
  PD of T3
  PE of (T1, T3)

nimlSpecial:
  *PP[T] = Piyo[int, int, T]
  *P = PP[string]

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

proc testMatch2(x: Hoge): bool =
  match x:
    HC:
      return true
    else:
      return true

proc testMatch3(x: Hoge): bool =
  match x:
    HA a:
      return true
    else:
      return true

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

let
  ppa = PP_PA[string](3)
  ppb = PP_PB[string](2, 3)
  ppc = PP_PC[string]()
  ppd = PP_PD[string]("hoge")
  ppe = PP_PE[string](2, "fuga")

let
  pppa = P_PP_PA(3)
  pppb = P_PP_PB(2, 3)
  pppc = P_PP_PC()
  pppd = P_PP_PD("hoge")
  pppe = P_PP_PE(2, "fuga")

doAssert testMatch ha
doAssert testMatch hb
doAssert testMatch hc
doAssert testMatch hd
doAssert testMatch he

doAssert testMatch2 ha
doAssert testMatch2 hb
doAssert testMatch2 hc
doAssert testMatch2 hd
doAssert testMatch2 he

doAssert testMatch3 ha
doAssert testMatch3 hb
doAssert testMatch3 hc
doAssert testMatch3 hd
doAssert testMatch3 he

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

doAssert testMatch ppa
doAssert testMatch ppb
doAssert testMatch ppc
doAssert testMatch ppd
doAssert testMatch ppe

doAssert testMatch pppa
doAssert testMatch pppb
doAssert testMatch pppc
doAssert testMatch pppd
doAssert testMatch pppe

#[
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

doAssert $pppa == "PA(3)"
doAssert $pppb == "PB(2, 3)"
doAssert $pppc == "PC"
doAssert $pppd == "PD(hoge)"
doAssert $pppe == "PE(2, fuga)"
]#

echo "Succeed"
