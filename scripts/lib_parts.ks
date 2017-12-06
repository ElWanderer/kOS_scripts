@LAZYGLOBAL OFF.
pOut("lib_parts.ks v1.2.0 20171206").

GLOBAL PART_DECOUPLERS IS LEXICON(
  "ModuleDockingNode", "decouple node",
  "ModuleDecouple", "decouple",
  "ModuleAnchoredDecoupler", "decouple").

IF SHIP:PARTSTAGGED("FINAL"):LENGTH = 0 { tagFinalParts(). }

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

FUNCTION modDo
{
  PARAMETER e, m.
  IF canEvent(e,m) { modEvent(e,m). RETURN TRUE. }
  RETURN FALSE.
}

FUNCTION partEvent
{
  PARAMETER e, mn, p.
  IF p:MODULES:CONTAINS(mn) { RETURN modDo(e, p:GETMODULE(mn)). }
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

FUNCTION isHeatShield
{
  PARAMETER p.
  RETURN p:NAME:TOLOWER:CONTAINS("heatshield") OR p:MODULES:CONTAINS("ModuleAblator").
}

FUNCTION isEngine
{
  PARAMETER p.
  RETURN p:MODULES:CONTAINS("ModuleEnginesFX") OR p:MODULES:CONTAINS("ModuleEngines").
}

FUNCTION fireEngine
{
  PARAMETER p.
  RETURN partEvent("Activate Engine", "ModuleEngines", p) OR partEvent("Activate Engine", "ModuleEnginesFX", p).
}

FUNCTION shutdownEngine
{
  PARAMETER p.
  RETURN partEvent("Shutdown Engine", "ModuleEngines", p) OR partEvent("Shutdown Engine", "ModuleEnginesFX", p).
}

FUNCTION stageIsFinal
{
  PARAMETER sn.
  FOR p IN SHIP:PARTSTAGGED("FINAL") { IF p:STAGE = sn { RETURN TRUE. } }
  RETURN FALSE.
}

FUNCTION tagFinalParts
{
  FOR p IN SHIP:PARTS {
    IF isDecoupler(p) AND p:HASPARENT AND isHeatShield(p:PARENT) {
      IF p:TAG = "" { SET p:TAG TO "FINAL". pOut("Adding tag FINAL to " + p:TITLE). }
      ELSE pOut("WARNING: think " + p:TITLE + " should be tagged FINAL, but it already has tag: " + p:TAG).
    }
  }
}
