@LAZYGLOBAL OFF.

GLOBAL RESUME_FN IS "resume.ks".
GLOBAL VOLUME_NAMES IS LIST().
listVolumes().
RUNONCEPATH(loadScript("init_common.ks",FALSE)).

pOut("init_multi.ks v1.1.2 20170116").
pVolumes().

FUNCTION setVolumeList
{
  PARAMETER vnl.
  SET VOLUME_NAMES TO vnl.
  pVolumes().
}

FUNCTION listVolumes
{
  LOCAL dn IS 0.
  IF CORE:CURRENTVOLUME:NAME = "" { SET CORE:CURRENTVOLUME:NAME TO CORE:TAG + "D" + dn. }
  SET VOLUME_NAMES TO LIST(CORE:CURRENTVOLUME:NAME).

  LOCAL pl IS LIST().
  LIST PROCESSORS IN pl.
  FOR p IN pl {
    LOCAL LOCK vn TO p:VOLUME:NAME.
    IF p:MODE = "READY" AND p:BOOTFILENAME = "None" AND p:UID <> CORE:UID AND
       ((p:TAG = "" AND CORE:TAG = "MULTI") OR (p:TAG = CORE:TAG AND CORE:TAG <> "MULTI")) {
      IF vn = "" {
        SET dn TO dn + 1.
        SET p:VOLUME:NAME TO (CORE:TAG + "D" + dn).
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
