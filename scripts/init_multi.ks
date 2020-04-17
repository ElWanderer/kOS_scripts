@LAZYGLOBAL OFF.

GLOBAL RESUME_FN IS "resume.ks".
GLOBAL VOLUME_NAMES IS LIST().
listVolumes().
RUNONCEPATH(loadScript("init_common.ks",FALSE)).

pOut("init_multi.ks v1.3.0 20200406").
pVolumes().

FUNCTION cOk
{
  RETURN HOMECONNECTION:ISCONNECTED.
}

FUNCTION setVolumeList
{
  PARAMETER vnl.
  SET VOLUME_NAMES TO vnl.
  pVolumes().
}

FUNCTION listVolumes
{
  LOCAL dn IS 0.
  LOCAL cp IS CORE:PART.
  IF CORE:CURRENTVOLUME:NAME = "" { SET CORE:CURRENTVOLUME:NAME TO cp:TAG + "D" + dn. }
  SET VOLUME_NAMES TO LIST(CORE:CURRENTVOLUME:NAME).

  LOCAL pl IS LIST().
  LIST PROCESSORS IN pl.
  FOR p IN pl {
    LOCAL pp IS p:PART.
    LOCAL LOCK vn TO p:VOLUME:NAME.
    IF p:MODE = "READY" AND p:BOOTFILENAME = "None" AND pp:UID <> cp:UID AND
       ((pp:TAG = "" AND cp:TAG = "MULTI") OR (pp:TAG = cp:TAG AND cp:TAG <> "MULTI")) {
      IF vn = "" {
        SET dn TO dn + 1.
        SET p:VOLUME:NAME TO (cp:TAG + "D" + dn).
      }
      VOLUME_NAMES:ADD(vn).
    }
  }
}

FUNCTION pVolumes
{
  FOR vn IN VOLUME_NAMES { pOut("Volume(" + vn + ") has " + VOLUME(vn):FREESPACE + " bytes."). }
}

FUNCTION findPath
{
  PARAMETER fn.
  FOR vn IN VOLUME_NAMES {
    LOCAL lfp IS vn + ":/" + fn.
    IF EXISTS(lfp) { RETURN lfp. }
  }
  RETURN "".
}

FUNCTION findSpace
{
  PARAMETER fn, mfs.
  FOR vn IN VOLUME_NAMES { IF VOLUME(vn):FREESPACE > mfs { RETURN vn + ":/" + fn. } }
  pOut("ERROR: no room!").
  pVolumes().
  RETURN "".
}

FUNCTION loadScript
{
  PARAMETER fn, loud IS TRUE.
  LOCAL lfp IS findPath(fn).
  IF lfp <> "" { RETURN lfp. }

  LOCAL afp IS "0:/" + fn.
  LOCAL afs IS VOLUME(0):OPEN(fn):SIZE.
  IF loud { pOut("Copying from: " + afp + " (" + afs + " bytes)"). }
  WAIT UNTIL cOk().
  SET lfp TO findSpace(fn, afs).
  COPYPATH(afp,lfp).
  IF loud { pOut("Copied to: " + lfp). }
  RETURN lfp.
}

FUNCTION delScript
{
  PARAMETER fn.
  LOCAL lfp IS findPath(fn).
  IF lfp <> "" { DELETEPATH(lfp). }
}

FUNCTION delResume
{
  delScript(RESUME_FN).
}

FUNCTION store
{
  PARAMETER t, fn IS RESUME_FN, mfs IS 150.
  delScript(fn).
  LOG t TO findSpace(fn,mfs).
}

FUNCTION storeJSON
{
  PARAMETER o, fn, mfs IS 150.
  LOCAL lfp IS findSpace(fn,mfs).
  IF lfp <> "" {
    delScript(fn).
    WRITEJSON(o, lfp).
  }
}

FUNCTION append
{
  PARAMETER t, fn IS RESUME_FN.
  LOG t TO findPath(fn).
}

FUNCTION resume
{
  PARAMETER fn IS RESUME_FN.
  LOCAL lfp IS findPath(fn).
  IF lfp <> "" { RUNPATH(lfp). }
}

FUNCTION hasFile
{
  PARAMETER fn.
  RETURN findPath(fn) <> "".
}

FUNCTION getJSON
{
  PARAMETER fn.
  RETURN READJSON(findPath(fn)).
}