@LAZYGLOBAL OFF.
RUNONCEPATH(loadScript("init_common.ks",FALSE)).

GLOBAL RESUME_FN IS "resume.ks".
pOut("init.ks v1.4.0 20200406").

FUNCTION cOk
{
  RETURN HOMECONNECTION:ISCONNECTED.
}

FUNCTION loadScript
{
  PARAMETER fn, loud IS TRUE.
  LOCAL lfp IS "1:/" + fn.
  IF EXISTS(lfp) { RETURN lfp. }

  LOCAL afp IS "0:/" + fn.
  IF loud { pOut("Copying: " + afp). }
  WAIT UNTIL cOk().
  COPYPATH(afp,lfp).
  IF loud { pOut("Copied to: " + lfp). }
  RETURN lfp.
}

FUNCTION delScript
{
  PARAMETER fn.
  LOCAL lfp IS "1:/" + fn.
  IF EXISTS(lfp) { DELETEPATH(lfp). }
}

FUNCTION delResume
{
  delScript(RESUME_FN).
}

FUNCTION store
{
  PARAMETER t, fn IS RESUME_FN, mfs IS 0.
  delScript(fn).
  LOG t TO ("1:/" + fn).
}

FUNCTION storeJSON
{
  PARAMETER o, fn, mfs IS 150.
  IF CORE:VOLUME:FREESPACE > mfs {
    delScript(fn).
    WRITEJSON(o, "1:/" + fn).
  }
}

FUNCTION append
{
  PARAMETER t, fn IS RESUME_FN.
  LOG t TO ("1:/" + fn).
}

FUNCTION resume
{
  PARAMETER fn IS RESUME_FN.
  LOCAL lfp IS "1:/" + fn.
  IF EXISTS(lfp) { RUNPATH(lfp). }
}

FUNCTION hasFile
{
  PARAMETER fn.
  RETURN EXISTS("1:/" + fn).
}

FUNCTION getJSON
{
  PARAMETER fn.
  RETURN READJSON("1:/" + fn).
}
