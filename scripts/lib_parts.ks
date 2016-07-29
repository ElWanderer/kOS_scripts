@LAZYGLOBAL OFF.
pOut("lib_parts.ks v1.0 20160714").

FUNCTION decouplePart

{
  PARAMETER d.
  IF d:MODULES:CONTAINS("ModuleDockingNode") {
    d:GETMODULE("ModuleDockingNode"):DOEVENT("decouple node").
  } ELSE IF d:MODULES:CONTAINS("ModuleAnchoredDecoupler") {
    d:GETMODULE("ModuleAnchoredDecoupler"):DOEVENT("decouple").
  } ELSE IF d:MODULES:CONTAINS("ModuleDecouple") {
    d:GETMODULE("ModuleDecouple"):DOEVENT("decouple").
  }
}

FUNCTION decoupleByTag
{
  PARAMETER p_tag.
  FOR dp IN SHIP:PARTSTAGGED(p_tag) { decouplePart(dp). }
}