@LAZYGLOBAL OFF.
pOut("lib_draw.ks v1.0.0 20180102").

GLOBAL DRAW_LIST IS LEXICON().

FUNCTION drawVector
{
  PARAMETER vname, sv, vv, l, c IS BLUE, s IS 1.0, w IS 0.2, vis IS TRUE.
  IF DRAW_LIST:HASKEY(vname) {
    SET DRAW_LIST[vname]:START TO sv.
    SET DRAW_LIST[vname]:VEC TO vv.
    SET DRAW_LIST[vname]:LABEL TO l.
    SET DRAW_LIST[vname]:COLOUR TO c.
    SET DRAW_LIST[vname]:SCALE TO s.
    SET DRAW_LIST[vname]:WIDTH TO w.
    SET DRAW_LIST[vname]:SHOW TO vis.
  } ELSE { DRAW_LIST:ADD(vname, VECDRAW(sv,vv,c,l,s,vis,w)). }
}

FUNCTION hideVector
{
  PARAMETER vname.
  IF DRAW_LIST:HASKEY(vname) { SET DRAW_LIST[vname]:SHOW TO FALSE. }
}

FUNCTION wipeVectors
{
  DRAW_LIST:CLEAR().
  CLEARVECDRAWS().
}