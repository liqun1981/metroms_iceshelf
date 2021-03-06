#include "cppdefs.h"
      SUBROUTINE wrt_rst (ng)
!
!svn $Id: wrt_rst.F 810 2016-08-05 01:58:16Z arango $
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2016 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.txt                                              !
!=======================================================================
!                                                                      !
!  This routine writes fields into restart NetCDF file.                !
!                                                                      !
!  Notice that only momentum is affected by the full time-averaged     !
!  masks.  If applicable, these mask contains information about        !
!  river runoff and time-dependent wetting and drying variations.      !
!                                                                      !
!=======================================================================
!
      USE mod_param
      USE mod_parallel
      USE mod_grid
      USE mod_iounits
      USE mod_mixing
      USE mod_ncparam
      USE mod_netcdf
      USE mod_ocean
      USE mod_scalars
#if defined SEDIMENT || defined BBL_MODEL
      USE mod_sedbed
      USE mod_sediment
#endif
      USE mod_stepping
!
      USE nf_fwrite2d_mod, ONLY : nf_fwrite2d
# if defined PERFECT_RESTART || defined SOLVE3D
      USE nf_fwrite3d_mod, ONLY : nf_fwrite3d
# endif
# if defined PERFECT_RESTART && defined SOLVE3D
      USE nf_fwrite4d_mod, ONLY : nf_fwrite4d
# endif
!
      implicit none
!
!  Imported variable declarations.
!
      integer, intent(in) :: ng
!
!  Local variable declarations.
!
      integer :: LBi, UBi, LBj, UBj
      integer :: Fcount, gfactor, gtype, i, itrc, status, varid
# if defined PERFECT_RESTART || defined SOLVE3D
      integer :: ntmp(1)
# endif
      real(r8) :: scale
!
      LBi=LBOUND(GRID(ng)%h,DIM=1)
      UBi=UBOUND(GRID(ng)%h,DIM=1)
      LBj=LBOUND(GRID(ng)%h,DIM=2)
      UBj=UBOUND(GRID(ng)%h,DIM=2)
!
      SourceFile='wrt_rst.F'
!
!-----------------------------------------------------------------------
!  Write out restart fields.
!-----------------------------------------------------------------------
!
      IF (exit_flag.ne.NoError) RETURN
!
!  Set grid type factor to write full (gfactor=1) fields or water
!  points (gfactor=-1) fields only.
!
#if !defined PERFECT_RESTART && \
    (defined WRITE_WATER && defined MASKING)
      gfactor=-1
#else
      gfactor=1
#endif
!
!  Set time record index.
!
      RST(ng)%Rindex=RST(ng)%Rindex+1
      Fcount=RST(ng)%Fcount
      RST(ng)%Nrec(Fcount)=RST(ng)%Nrec(Fcount)+1
!
!  If requested, set time index to recycle time records in restart
!  file.
!
      IF (LcycleRST(ng)) THEN
        RST(ng)%Rindex=MOD(RST(ng)%Rindex-1,2)+1
      END IF

#ifdef PERFECT_RESTART
!
!  Write out time-stepping indices.
!
# ifdef SOLVE3D
      ntmp(1)=1+MOD((iic(ng)-1)-ntstart(ng),2)
      CALL netcdf_put_ivar (ng, iNLM, RST(ng)%name, 'nstp',             &
     &                      ntmp, (/RST(ng)%Rindex/), (/1/),            &
     &                      ncid = RST(ng)%ncid)
      IF (exit_flag.ne.NoError) RETURN

      CALL netcdf_put_ivar (ng, iNLM, RST(ng)%name, 'nrhs',             &
     &                      ntmp, (/RST(ng)%Rindex/), (/1/),            &
     &                      ncid = RST(ng)%ncid)
      IF (exit_flag.ne.NoError) RETURN

      ntmp(1)=3-ntmp(1)
      CALL netcdf_put_ivar (ng, iNLM, RST(ng)%name, 'nnew',             &
     &                      ntmp, (/RST(ng)%Rindex/), (/1/),            &
     &                      ncid = RST(ng)%ncid)
      IF (exit_flag.ne.NoError) RETURN
# endif
      CALL netcdf_put_ivar (ng, iNLM, RST(ng)%name, 'kstp',             &
     &                      kstp(ng:), (/RST(ng)%Rindex/), (/1/),       &
     &                      ncid = RST(ng)%ncid)
      IF (exit_flag.ne.NoError) RETURN

      CALL netcdf_put_ivar (ng, iNLM, RST(ng)%name, 'krhs',             &
     &                      krhs(ng:), (/RST(ng)%Rindex/), (/1/),       &
     &                      ncid = RST(ng)%ncid)
      IF (exit_flag.ne.NoError) RETURN

      CALL netcdf_put_ivar (ng, iNLM, RST(ng)%name, 'knew',             &
     &                      knew(ng:), (/RST(ng)%Rindex/), (/1/),       &
     &                      ncid = RST(ng)%ncid)
      IF (exit_flag.ne.NoError) RETURN
#endif
!
!  Write out model time (s).
!
      CALL netcdf_put_fvar (ng, iNLM, RST(ng)%name,                     &
     &                      TRIM(Vname(idtime,ng)), time(ng:),          &
     &                      (/RST(ng)%Rindex/), (/1/),                  &
     &                      ncid = RST(ng)%ncid,                        &
     &                      varid = RST(ng)%Vid(idtime))
      IF (exit_flag.ne.NoError) RETURN
#if defined ICESHELF && defined ICESHELF_MORPH
!
!  Write out time-dependent ice draft (m)
!
      IF (Hout(iddraft,ng)) THEN
        scale=1.0_r8
        gtype=gfactor*r2dvar
        status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(iddraft),&
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
# ifdef MASKING
     &                     GRID(ng) % rmask,                            &
# endif
     &                     GRID(ng) % zice,                             &
     &                     SetFillVal = .FALSE.)
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,iddraft)), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
#endif
#if defined SEDIMENT && defined SED_MORPH
!
!  Write out time-dependent bathymetry (m)
!
      IF (Hout(idbath,ng)) THEN
        scale=1.0_r8
        gtype=gfactor*r2dvar
        status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idbath), &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
# ifdef MASKING
     &                     GRID(ng) % rmask,                            &
# endif
     &                     GRID(ng) % h,                                &
     &                     SetFillVal = .FALSE.)
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idbath)), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END IF
#endif
#ifdef WET_DRY
!
!  Write out wet/dry mask at PSI-points.
!
      scale=1.0_r8
      gtype=gfactor*p2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idPwet),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % pmask,                              &
# endif
     &                   GRID(ng) % pmask_wet,                          &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idPwet)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
!
!  Write out wet/dry mask at RHO-points.
!
      scale=1.0_r8
      gtype=gfactor*r2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idRwet),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % rmask,                              &
# endif
     &                   GRID(ng) % rmask_wet,                          &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idRwet)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
!
!  Write out wet/dry mask at U-points.
!
      scale=1.0_r8
      gtype=gfactor*u2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idUwet),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % umask,                              &
# endif
     &                   GRID(ng) % umask_wet,                          &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idUwet)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
!
!  Write out wet/dry mask at V-points.
!
      scale=1.0_r8
      gtype=gfactor*v2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVwet),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % vmask,                              &
# endif
     &                   GRID(ng) % vmask_wet,                          &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idVwet)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#endif
!
!  Write out free-surface (m).
!
      scale=1.0_r8
#ifdef PERFECT_RESTART
      gtype=gfactor*r3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idFsur),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, 3, scale,               &
# ifdef MASKING
     &                   GRID(ng) % rmask,                              &
# endif
# ifdef WET_DRY
     &                   OCEAN(ng) % zeta,                              &
     &                   SetFillVal = .FALSE.)
# else
     &                   OCEAN(ng) % zeta)
# endif
#else
      gtype=gfactor*r2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idFsur),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % rmask,                              &
# endif
# ifdef WET_DRY
     &                   OCEAN(ng) % zeta(:,:,KOUT),                    &
     &                   SetFillVal = .FALSE.)
# else
     &                   OCEAN(ng) % zeta(:,:,KOUT))
# endif
#endif
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idFsur)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#ifdef PERFECT_RESTART
!
!  Write out RHS of free-surface equation.
!
      scale=1.0_r8
      gtype=gfactor*r3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idRzet),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, 2, scale,               &
# ifdef MASKING
     &                   GRID(ng) % rmask,                              &
# endif
     &                   OCEAN(ng) % rzeta)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idRzet)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#endif
!
!  Write out 2D momentum component (m/s) in the XI-direction.
!
      scale=1.0_r8
#ifdef PERFECT_RESTART
      gtype=gfactor*u3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idUbar),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, 3, scale,               &
# ifdef MASKING
     &                   GRID(ng) % umask,                              &
# endif
     &                   OCEAN(ng) % ubar,                              &
     &                   SetFillVal = .FALSE.)

#else
      gtype=gfactor*u2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idUbar),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % umask_full,                         &
# endif
     &                   OCEAN(ng) % ubar(:,:,KOUT))
#endif
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idUbar)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#ifdef PERFECT_RESTART
!
!  Write out RHS of 2D momentum equation in the XI-direction.
!
      scale=1.0_r8
      gtype=gfactor*u3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idRu2d),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, 2, scale,               &
# ifdef MASKING
     &                   GRID(ng) % umask,                              &
# endif
     &                   OCEAN(ng) % rubar,                             &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idRu2d)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#endif
!
!  Write out 2D momentum component (m/s) in the ETA-direction.
!
      scale=1.0_r8
#ifdef PERFECT_RESTART
      gtype=gfactor*v3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVbar),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, 3, scale,               &
# ifdef MASKING
     &                   GRID(ng) % vmask,                              &
# endif
     &                   OCEAN(ng) % vbar,                              &
     &                   SetFillVal = .FALSE.)
#else
      gtype=gfactor*v2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVbar),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % vmask_full,                         &
# endif
     &                   OCEAN(ng) % vbar(:,:,KOUT))
#endif
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idVbar)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#ifdef PERFECT_RESTART
!
!  Write out RHS of 2D momentum equation in the ETA-direction.
!
      scale=1.0_r8
      gtype=gfactor*v3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idRv2d),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, 2, scale,               &
# ifdef MASKING
     &                   GRID(ng) % vmask,                              &
# endif
     &                   OCEAN(ng) % rvbar,                             &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idRv2d)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#endif
#ifdef SOLVE3D
!
!  Write out 3D momentum component (m/s) in the XI-direction.
!
      scale=1.0_r8
      gtype=gfactor*u3dvar
# ifdef PERFECT_RESTART
      status=nf_fwrite4d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idUvel),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, N(ng), 1, 2, scale,     &
#  ifdef MASKING
     &                   GRID(ng) % umask,                              &
#  endif
     &                   OCEAN(ng) % u,                                 &
     &                   SetFillVal = .FALSE.)
# else
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idUvel),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % umask_full,                         &
#  endif
     &                   OCEAN(ng) % u(:,:,:,NOUT))
# endif
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idUvel)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
# ifdef PERFECT_RESTART
!
!  Write out RHS of 3D momentum equation in the XI-direction.
!
      scale=1.0_r8
      gtype=gfactor*u3dvar
      status=nf_fwrite4d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idRu3d),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), 1, 2, scale,     &
#  ifdef MASKING
     &                   GRID(ng) % umask,                              &
#  endif
     &                   OCEAN(ng) % ru,                                &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idRu3d)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
# endif
!
!  Write out momentum component (m/s) in the ETA-direction.
!
      scale=1.0_r8
      gtype=gfactor*v3dvar
# ifdef PERFECT_RESTART
      status=nf_fwrite4d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVvel),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, N(ng), 1, 2, scale,     &
#  ifdef MASKING
     &                   GRID(ng) % vmask,                              &
#  endif
     &                   OCEAN(ng) % v,                                 &
     &                   SetFillVal = .FALSE.)
# else
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVvel),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % vmask_full,                         &
#  endif
     &                   OCEAN(ng) % v(:,:,:,NOUT))
# endif
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idVvel)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
# ifdef PERFECT_RESTART
!
!  Write out RHS of 3D momentum equation in the ETA-direction.
!
      scale=1.0_r8
      gtype=gfactor*v3dvar
      status=nf_fwrite4d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idRv3d),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), 1, 2, scale,     &
#  ifdef MASKING
     &                   GRID(ng) % vmask,                              &
#  endif
     &                   OCEAN(ng) % rv,                                &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idRv3d)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
# endif
!
!  Write out tracer type variables.
!
      DO itrc=1,NT(ng)
        scale=1.0_r8
        gtype=gfactor*r3dvar
# ifdef PERFECT_RESTART
        status=nf_fwrite4d(ng, iNLM, RST(ng)%ncid, RST(ng)%Tid(itrc),   &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, N(ng), 1, 2, scale,   &
#  ifdef MASKING
     &                     GRID(ng) % rmask,                            &
#  endif
     &                     OCEAN(ng) % t(:,:,:,:,itrc))
# else
        status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Tid(itrc),   &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, N(ng), scale,         &
#  ifdef MASKING
     &                     GRID(ng) % rmask,                            &
#  endif
     &                     OCEAN(ng) % t(:,:,:,NOUT,itrc))
# endif
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idTvar(itrc))), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END DO
!
!  Write out density anomaly.
!
      scale=1.0_r8
      gtype=gfactor*r3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idDano),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, N(ng), scale,           &
# ifdef MASKING
     &                   GRID(ng) % rmask,                              &
# endif
     &                   OCEAN(ng) % rho)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idDano)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
# ifdef LMD_SKPP
!
!  Write out depth of surface boundary layer.
!
      scale=1.0_r8
      gtype=gfactor*r2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idHsbl),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % hsbl)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idHsbl)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
# endif
# ifdef LMD_BKPP
!
!  Write out depth of bottom boundary layer.
!
      scale=1.0_r8
      gtype=gfactor*r2dvar
      status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idHbbl),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % hbbl)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idHbbl)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
# endif
# if defined PERFECT_RESTART && defined LMD_NONLOCAL
!
!  Write out KPP nonlocal transport.
!
      DO i=1,NAT
        scale=1.0_r8
        gtype=gfactor*w3dvar
        status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid,                      &
     &                       RST(ng)%Vid(idGhat(i)),                    &
     &                       RST(ng)%Rindex, gtype,                     &
     &                       LBi, UBi, LBj, UBj, 0, N(ng), scale,       &
#  ifdef MASKING
     &                       GRID(ng) % rmask,                          &
#  endif
     &                       MIXING(ng) % ghats(:,:,:,i))
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idGhat(i))), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END DO
# endif
# if defined BVF_MIXING  || defined GLS_MIXING || \
     defined MY25_MIXING || defined LMD_MIXING
!
!  Write out vertical viscosity coefficient.
!
      scale=1.0_r8
      gtype=gfactor*w3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVvis),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % Akv,                              &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idVvis)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
!
!  Write out vertical diffusion coefficient for potential temperature.
!
      scale=1.0_r8
      gtype=gfactor*w3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idTdif),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % Akt(:,:,:,itemp),                 &
     &                   SetFillVal = .FALSE.)

      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idTdif)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#  ifdef SALINITY
!
!  Write out vertical diffusion coefficient for salinity.
!
      scale=1.0_r8
      gtype=gfactor*w3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idSdif),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), scale,           &
#   ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#   endif
     &                   MIXING(ng) % Akt(:,:,:,isalt),                 &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idSdif)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#  endif
# endif
# if defined PERFECT_RESTART && \
     (defined GLS_MIXING     || defined MY25_MIXING)
!
!  Write out turbulent kinetic energy.
!
      scale=1.0_r8
      gtype=gfactor*w3dvar
      status=nf_fwrite4d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idMtke),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), 1, 2, scale,     &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % tke,                              &
     &                   SetFillVal = .FALSE.)

      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idMtke)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
!
!  Define turbulent kinetic energy time length scale.
!
      scale=1.0_r8
      gtype=gfactor*w3dvar
      status=nf_fwrite4d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idMtls),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), 1, 2, scale,     &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % gls,                              &
     &                   SetFillVal = .FALSE.)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idMtls)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
!
!  Define vertical mixing turbulent length scale.
!
      scale=1.0_r8
      gtype=gfactor*w3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVmLS),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % Lscale)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idVmLS)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
!
!  Define turbulent kinetic energy vertical diffusion coefficient.
!
      scale=1.0_r8
      gtype=gfactor*w3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVmKK),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % Akk)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idVmKK)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#  ifdef GLS_MIXING
!
!  Define turbulent length scale vertical diffusion coefficient.
!
      scale=1.0_r8
      gtype=gfactor*w3dvar
      status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idVmKP),   &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 0, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % rmask,                              &
#  endif
     &                   MIXING(ng) % Akp)
      IF (status.ne.nf90_noerr) THEN
        IF (Master) THEN
          WRITE (stdout,10) TRIM(Vname(1,idVmKP)), RST(ng)%Rindex
        END IF
        exit_flag=3
        ioerror=status
        RETURN
      END IF
#  endif
# endif
# ifdef SEDIMENT
#  ifdef BEDLOAD
!
!  Write out bed load transport in U-direction.
!
      DO i=1,NST
        scale=1.0_r8
        gtype=gfactor*u2dvar
        status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid,                      &
     &                     RST(ng)%Vid(idUbld(i)),                      &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
#   ifdef MASKING
     &                     GRID(ng) % umask,                            &
#   endif
     &                     SEDBED(ng) % bedldu(:,:,i))
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idUbld(i))), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END DO
!
!  Write out bed load transport in V-direction.
!
      DO i=1,NST
        scale=1.0_r8
        gtype=gfactor*v2dvar
        status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid,                      &
     &                     RST(ng)%Vid(idVbld(i)),                      &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
#   ifdef MASKING
     &                     GRID(ng) % vmask,                            &
#   endif
     &                     SEDBED(ng) % bedldv(:,:,i))
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idVbld(i))), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END DO
#  endif
!
!  Write out sediment fraction of each size class in each bed layer.
!
      DO i=1,NST
        scale=1.0_r8
        gtype=gfactor*b3dvar
        status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid,                      &
     &                     RST(ng)%Vid(idfrac(i)),                      &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, Nbed, scale,          &
#  ifdef MASKING
     &                     GRID(ng) % rmask,                            &
#  endif
     &                     SEDBED(ng) % bed_frac(:,:,:,i))
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idfrac(i))), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END DO
!
!  Write out sediment mass of each size class in each bed layer.
!
      DO i=1,NST
        scale=1.0_r8
        gtype=gfactor*b3dvar
        status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid,                      &
     &                     RST(ng)%Vid(idBmas(i)),                      &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, Nbed, scale,          &
#  ifdef MASKING
     &                     GRID(ng) % rmask,                            &
#  endif
     &                     SEDBED(ng) % bed_mass(:,:,:,NOUT,i))
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idBmas(i))), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END DO
!
!  Write out sediment properties in each bed layer.
!
      DO i=1,MBEDP
        IF (i.eq.itauc) THEN
          scale=rho0
        ELSE
          scale=1.0_r8
        END IF
        gtype=gfactor*b3dvar
        status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid,                      &
     &                     RST(ng)%Vid(idSbed(i)),                      &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, 1, Nbed, scale,          &
#  ifdef MASKING
     &                     GRID(ng) % rmask,                            &
#  endif
     &                     SEDBED(ng) % bed(:,:,:,i))
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idSbed(i))), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END DO
# endif
# if defined SEDIMENT || defined BBL_MODEL
!
!  Write out exposed sediment layer properties. Notice that only the
!  first four properties (mean grain diameter, mean grain density,
!  mean settling velocity, mean critical erosion stress,
!  ripple length and ripple height) are written.
!
      DO i=1,6
        scale=1.0_r8
        gtype=gfactor*r2dvar
        status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid,                      &
     &                     RST(ng)%Vid(idBott(i)),                      &
     &                     RST(ng)%Rindex, gtype,                       &
     &                     LBi, UBi, LBj, UBj, scale,                   &
#  ifdef MASKING
     &                     GRID(ng) % rmask,                            &
#  endif
     &                     SEDBED(ng) % bottom(:,:,i))
        IF (status.ne.nf90_noerr) THEN
          IF (Master) THEN
            WRITE (stdout,10) TRIM(Vname(1,idBott(i))), RST(ng)%Rindex
          END IF
          exit_flag=3
          ioerror=status
          RETURN
        END IF
      END DO
# endif
#endif
#ifdef NEARSHORE_MELLOR
!
!  Write out 2D U-momentum stokes velocity.
!
        scale=1.0_r8
        gtype=gfactor*u2dvar
        status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idU2Sd), &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % umask,                              &
# endif
     &                   OCEAN(ng) % ubar_stokes)
        IF (status.ne.nf90_noerr) THEN
          IF (Master) WRITE (stdout,10) TRIM(Vname(1,idU2Sd)),          &
     &                                  RST(ng)%Rindex
          exit_flag=3
          ioerror=status
          RETURN
        END IF
!
!  Write out 2D V-momentum stokes velocity.
!
        scale=1.0_r8
        gtype=gfactor*v2dvar
        status=nf_fwrite2d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idV2Sd), &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, scale,                     &
# ifdef MASKING
     &                   GRID(ng) % vmask,                              &
# endif
     &                   OCEAN(ng) % vbar_stokes)
        IF (status.ne.nf90_noerr) THEN
          IF (Master) WRITE (stdout,10) TRIM(Vname(1,idV2Sd)),          &
     &                                  RST(ng)%Rindex
          exit_flag=3
          ioerror=status
          RETURN
        END IF
# ifdef SOLVE3D
!
!  Write out 3D U-momentum stokes velocity.
!
        scale=1.0_r8
        gtype=gfactor*u3dvar
        status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idU3Sd), &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % umask,                              &
#  endif
     &                   OCEAN(ng) % u_stokes)
        IF (status.ne.nf90_noerr) THEN
          IF(Master) WRITE (stdout,10) TRIM(Vname(1,idU3Sd)),           &
     &                                 RST(ng)%Rindex
          exit_flag=3
          ioerror=status
          RETURN
        END IF
!
!  Write out 3D V-momentum stokes velocity.
!
        scale=1.0_r8
        gtype=gfactor*v3dvar
        status=nf_fwrite3d(ng, iNLM, RST(ng)%ncid, RST(ng)%Vid(idV3Sd), &
     &                   RST(ng)%Rindex, gtype,                         &
     &                   LBi, UBi, LBj, UBj, 1, N(ng), scale,           &
#  ifdef MASKING
     &                   GRID(ng) % vmask,                              &
#  endif
     &                   OCEAN(ng) % v_stokes)
        IF (status.ne.nf90_noerr) THEN
          IF (Master) WRITE (stdout,10) TRIM(Vname(1,idV3Sd)),          &
     &                                  RST(ng)%Rindex
          exit_flag=3
          ioerror=status
          RETURN
        END IF
# endif
#endif
!
!-----------------------------------------------------------------------
!  Synchronize restart NetCDF file to disk.
!-----------------------------------------------------------------------
!
      CALL netcdf_sync (ng, iNLM, RST(ng)%name, RST(ng)%ncid)
      IF (exit_flag.ne.NoError) RETURN

#ifdef SOLVE3D
# ifdef NESTING
      IF (Master) WRITE (stdout,20) KOUT, NOUT, RST(ng)%Rindex, ng
# else
      IF (Master) WRITE (stdout,20) KOUT, NOUT, RST(ng)%Rindex
# endif
#else
# ifdef NESTING
      IF (Master) WRITE (stdout,20) KOUT, RST(ng)%Rindex, ng
# else
      IF (Master) WRITE (stdout,20) KOUT, RST(ng)%Rindex
# endif
#endif
!
  10  FORMAT (/,' WRT_RST - error while writing variable: ',a,/,11x,    &
     &        'into restart NetCDF file for time record: ',i4)

#ifdef SOLVE3D
  20  FORMAT (6x,'WRT_RST     - wrote re-start', t39,                   &
# ifdef NESTING
     &        'fields (Index=',i1,',',i1,') in record = ',i7.7,2x,i2.2)
# else
     &        'fields (Index=',i1,',',i1,') in record = ',i7.7)
# endif
#else
  20  FORMAT (6x,'WRT_RST     - wrote re-start', t39,                   &
# ifdef NESTING
     &        'fields (Index=',i1,')   in record = ',i7.7,2x,i2.2)
# else
     &        'fields (Index=',i1,')   in record = ',i7.7)
# endif
#endif

      RETURN
      END SUBROUTINE wrt_rst
