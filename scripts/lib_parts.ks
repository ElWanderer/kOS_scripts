@LAZYGLOBAL OFF.
pOut("lib_parts.ks v1.1.0 20161110").

FUNCTION canEvent
{
  PARAMETER e, m.
  RETURN m:HASEVENT(e).
}

FUNCTION modEvent
{
  PARAMETER e, m.
  m:DOEVENT(e).
  pOut(m:PART:TITLE + ": " + e).
}

FUNCTION partEvent
{
  PARAMETER e, mn, p.
  IF p:MODULES:CONTAINS(mn) {
    LOCAL m IS p:GETMODULE(mn).
    IF canEvent(e,m) { modEvent(e,m). RETURN TRUE. }
  }
  RETURN FALSE.
}

FUNCTION modField
{
  PARAMETER fn, m.
  IF m:HASFIELD(fn) { RETURN m:GETFIELD(fn). }
  RETURN "-".
}

FUNCTION partModField
{
  PARAMETER fn, mn, p.
  IF p:MODULES:CONTAINS(mn) { RETURN modField(fn, p:GETMODULE(mn)). }
  RETURN "-".
}

FUNCTION decouplePart
{
  PARAMETER p.

  IF NOT (partEvent("decouple node","ModuleDockingNode",p)
  OR partEvent("decouple","ModuleDecouple",p)
  OR partEvent("decouple","ModuleAnchoredDecoupler",p))
  AND p:HASPARENT { decouplePart(p:PARENT). }
}

FUNCTION decoupleByTag
{
  PARAMETER t.
  FOR p IN SHIP:PARTSTAGGED(t) { decouplePart(p). }
}
