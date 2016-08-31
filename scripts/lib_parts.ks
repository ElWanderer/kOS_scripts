@LAZYGLOBAL OFF.
pOut("lib_parts.ks v1.0.1 20160831").

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
