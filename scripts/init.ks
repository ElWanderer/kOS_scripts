@LAZYGLOBAL OFF.

COPYPATH("0:/init_common.ks","1:/init_common.ks").
RUNONCEPATH("1:/init_common.ks").

GLOBAL RESUME_FN IS "resume.ks".
pOut("init.ks v1.2.1 20160726").

FUNCTION loadScript
{
  PARAMETER fn.
  LOCAL lfp IS "1:/" + fn.
  IF EXISTS(lfp) { RETURN lfp. }

  LOCAL afp IS "0:/" + fn.
  LOCAL afs IS VOLUME(0):OPEN(fn):SIZE.
  pOut("Copying " + afp + " (" + afs + ") to " + lfp).
  COPYPATH(afp,lfp).
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