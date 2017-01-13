@LAZYGLOBAL OFF.
pOut("lib_parts.ks v1.2.0 20170113").

GLOBAL PART_DECOUPLERS IS LEXICON(
  "ModuleDockingNode", "decouple node",
  "ModuleDecouple", "decouple",
  "ModuleAnchoredDecoupler", "decouple").

// test lines
GLOBAL PART_HIGHLIGHTS IS LIST().

FUNCTION clearHighlights
{
  FOR ph IN PART_HIGHLIGHTS { SET ph:ENABLED TO FALSE. }
  PART_HIGHLIGHTS:CLEAR.
}

FUNCTION partHighlight
{
  PARAMETER p, c IS RGB(0,1,0).
  PART_HIGHLIGHTS:ADD(HIGHLIGHT(p,c)).
}
// end of test lines

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

FUNCTION isDecoupler
{
  PARAMETER p.
  FOR mn IN p:MODULES { IF PART_DECOUPLERS:HASKEY(mn) { RETURN TRUE. } }
  RETURN FALSE.
}

FUNCTION decouplePart
{
  PARAMETER p, tr IS TRUE.
  IF isDecoupler(p) { FOR mn IN PART_DECOUPLERS:KEYS { partEvent(PART_DECOUPLERS[mn],mn,p). } }
  ELSE IF tr { IF p:HASPARENT { decouplePart(p:PARENT). } ELSE { decouplePart(p, FALSE). } }
  ELSE { FOR cp IN p:CHILDREN { decouplePart(cp,tr). } }
}

FUNCTION decoupleByTag
{
  PARAMETER t.
  FOR p IN SHIP:PARTSTAGGED(t) { decouplePart(p). }
}
