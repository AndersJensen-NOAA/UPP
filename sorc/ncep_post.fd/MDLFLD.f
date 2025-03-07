!> @file
!
!> SUBPROGRAM:    MDLFLD      SLP AND NATIVE LEVEL POSTING
!!   PRGRMMR: TREADON         ORG: W/NP2      DATE: 92-12-21       
!!     
!! ABSTRACT:
!!     THIS ROUTINE DOES SEVERAL THINGS.  IT IS THE FIRST 
!!     ROUTINE CALLED BY POST PROCESSOR SUBROUTINE PROCESS 
!!     WHICH SETS THE ORDER IN WHICH FIELDS ARE POSTED.  THE
!!     NEGATIVE SPECIFIC HUMIDITY IS CLIPPED.
!!     COMPUTE THE STANDARD NMC SEA LEVEL PRESSURE IF THIS OPTION
!!     IS ACTIVATED.  FINALLY WE COMPUTE/POST REQUESTED FIELDS ON
!!     MODEL LAYERS.
!!
!! PROGRAM HISTORY LOG:
!!   92-12-21  RUSS TREADON
!!   93-09-01  RUSS TREADON - ADDED ADDITIONAL OUTPUT FIELDS.
!!   96-03-20  MIKE BALDWIN - ADDED CLOUD TOP TEMPS, CHANGE CLOUD WATER
!!                            TO CONTAIN WATER ONLY
!!   97-04-29  GEOFF MANIKIN - MOVED CLOUD TOP TEMPS TO CLDRAD
!!   98-06-01  T BLACK - CONVERSION FROM 1-D TO 2-D
!!   98-07-20  MIKE BALDWIN - REMOVED LABL84
!!   98-08-18  T BLACK - REMOVED EXCESS SPACE IN EXTRA.com
!!   00-01-04  JIM TUCCILLO - MPI VERSION
!!   01-10-22  H CHUANG - MODIFIED TO PROCESS HYBRID MODEL OUTPUT
!!   02-01-15  MIKE BALDWIN - WRF VERSION
!!   04-11-17  H CHUANG, B FERRIER, AND Y JIN - ADD HYDROMETEORS, 
!!					VISIBILITY & RADAR REFLECTIVITY
!!   05-07-07  B ZHOU ADD RSM MODEL A GRID     
!!   05-08-18  B ZHOU ADD /VISB/ COMMON BLOCK TO PASS VISIBILITY TO
!!                        AVIATION SUBROUTINE TO CALCULATE FLIGHT
!!                        CONDITION RESTRICTION
!!   11-02-06  J Wang - add grib2 option
!!   12-01-06  S LU - MODIFIED TO PROCESS GOCART OUTPUT 
!!   12-01-21  S LU - MODIFIED TO PROCESS NON-DUST AEROSOLS
!!   14-02-27  S MOORTHI - Added threading and some cleanup
!!   14-11-17  B ZHOU - Undetected ECHO TOP value is modified from SPVAL to -5000.
!!   15-xx-xx  S. Moorthi - reduced memory version
!!   15-11-03  S Moorthi - fix a bug in "RELATIVE HUMIDITY ON MDLSURFACES" sectio logic
!!   19-10-30  Bo CUI - REMOVE "GOTO" STATEMENT
!!   20-03-24  J MENG - remove grib1
!!   20-05-20  J MENG - CALRH unification with NAM scheme
!!   20-11-10  J MENG - USE UPP_MATH MODULE
!!   20-11-10  J MENG - USE UPP_PHYSICS MODULE
!!   21-04-01  J MENG - COMPUTATION ON DEFINED POINTS ONLY
!!   21-07-07  J MENG - 2D DECOMPOSITION
!!   22-05-25  Y Mao - Add WAFS icing/turbulence on pressure levels
!!   22-09-22  L Zhang - ADD NO3 and NH4 output for UFS-Aerosols model
!!   22-10-20  W Meng - Bug fix for cloud fraction and vertically integrated liquid
!!   22-11-08  W Meng - Output hourly averaged PM2.5 and O3 for AQM model only (aqf_on) 
!!   22-11-16  E James - Adding dust from RRFS
!!   23-02-10  E James - Adding an extra IGET value to if statement for NGMSLP calculation
!!   23-02-23  E James - Adding coarse PM from RRFS
!!   23-03-03  S Trahan - Avoid out-of-bounds access in U2H & V2H by using USTORE & VSTORE with halo bounds
!!   23-04-04 | Li(Kate Zhang)  |Add namelist optoin for CCPP-Chem (UFS-Chem) 
!!   23-06-26 | W Meng | Output composite radar reflectivity when GFS uses Thompson MP
!!   23-08-16 | Y Mao  | For gtg_algo, add tke as an input and cit as an output
!!   23-08-16 | Y Mao  | For GTG, replace iget(ID) with namelist option 'gtg_on'.
!!   23-10-04 | W Meng | Read 3D radar reflectivity from model when GFS use Thmopson MP
!!   23-10-17 | E James| Include hail hydrometeors in VIL computation when available
!!   24-01-07 | Y Mao  | Add EDPARM IDs to the condition to call gtg_algo()
!!   24-01-24 | H Lin  | switching GTG max (gtg) to gtgx3 from gtgx2 per gtg_algo() call
!!
!! USAGE:    CALL MDLFLD
!!   INPUT ARGUMENT LIST:
!!
!!   OUTPUT ARGUMENT LIST: 
!!     NONE
!!
!!   OUTPUT FILES:
!!     NONE
!!     
!!   SUBPROGRAMS CALLED:
!!     UTILITIES:
!!       BOUND    - BOUND ARRAY ELEMENTS BETWEEN LOWER AND UPPER LIMITS.
!!       SCLFLD   - SCALE ARRAY ELEMENTS BY SCALAR CONSTANT.
!!       NGMSLP   - COMPUTE SLP USING STANDARD NMC REDUCTION METHOD.
!!       CALPOT   - COMPUTE POTENTIAL TEMPERATURE.
!!       CALRH    - COMPUTE RELATIVE HUMIDITY.
!!       CALDWP   - COMPUTE DEWPOINT TEMPERATURE.
!!       CALMCVG  - COMPUTE MOISTURE CONVERGENCE.
!!       CALVOR   - COMPUTE ABSOLUTE VORTICITY.
!!       CALSTRM  - COMPUTE GEOSTROPHIC STREAMFUNCTION.
!!       CALMICT_new  - COMPUTES CLOUD FIELDS AND RADAR REFLECTIVITY
!!                    FACTOR FOR FERRIER-ALIGO
!!       CALMICT_old  - COMPUTES CLOUD FIELDS AND RADAR REFLECTIVITY
!!                    FACTOR FOR OTHER FERRIER OPTIONS
!!     LIBRARY:
!!       COMMON   - 
!!                  RQSTFLD
!!                  CTLBLK
!!     
!!   ATTRIBUTES:
!!     LANGUAGE: FORTRAN
!!     MACHINE : CRAY C-90
!!
      SUBROUTINE MDLFLD

!    
      use vrbls4d, only: dust, salt, suso, waso, soot, no3, nh4, smoke, fv3dust,&
              coarsepm
      use vrbls3d, only: zmid, t, pmid, q, cwm, f_ice, f_rain, f_rimef, qqw, qqi,&
              qqr, qqs, cfr, cfr_raw, dbz, dbzr, dbzi, dbzc, qqw, nlice, nrain, qqg, qqh, zint,&
              qqni, qqnr, qqnw, qqnwfa, qqnifa, uh, vh, mcvg, omga, wh, q2, ttnd, rswtt, &
              rlwtt, train, tcucn, o3, rhomid, dpres, el_pbl, pint, icing_gfip, icing_gfis, &
              catedr,mwt,gtg,cit, REF_10CM, avgpmtf, avgozcon

      use vrbls2d, only: slp, hbot, htop, cnvcfr, cprate, cnvcfr, sfcshx,sfclhx,ustar,z0,&
              sr, prec, vis, czen, pblh, pblhgust, u10, v10, avgprec, avgcprate, &
              REF1KM_10CM,REF4KM_10CM,REFC_10CM,REFD_MAX
      use masks, only: lmh, gdlat, gdlon,sm,sice,dx,dy
      use params_mod, only: rd, gi, g, rog, h1, tfrz, d00, dbzmin, d608, small,&
              h100, h1m12, h99999,pi,ERAD
      use pmicrph_mod, only: r1, const1r, qr0, delqr0, const2r, ron, topr, son,&
              tops, dsnow, drain,const_ng1, const_ng2, gon, topg, dgraupel
      use ctlblk_mod, only: jsta_2l, jend_2u, lm, jsta, jend, grib, cfld, datapd,&
              fld_info, modelname, imp_physics, dtq2, spval, icount_calmict,&
              me, dt, avrain, theat, ifhr, ifmin, avcnvc, lp1, im, jm, &
      ista, iend, ista_2l, iend_2u, aqf_on, gocart_on, gccpp_on, nasa_on, gtg_on
      use rqstfld_mod, only: iget, id, lvls, iavblfld, lvlsxml
      use gridspec_mod, only: gridtype,maptype,dxval
      use upp_physics, only: CALRH, CALCAPE, CALVOR
      use upp_math, only: H2U, H2V, U2H, V2H

!     
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       implicit none
!
      REAL, PARAMETER :: CURATE=24.*1000., CTIM1=0., CTIM2=24.*3600.    &
     &, RAINCON=0.8333*1.1787E4, SNOCON=0.94*1.4594E5                   &
! specify in params now
!
!--- 88D reflectivity algorithm, Z = 300.*R**1.4 , R is rain rate in mm/h
!
     &, DBZmax=80., ZR_A=300., ZR_B=1.4
!
!--- Modification of Slingo (1987) to enhance convective cloudiness
!
      REAL CC(10), PPT(10)
      DATA CC / 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0 /
      DATA PPT/  0., .14, .31, .70, 1.6, 3.4, 7.7, 17., 38., 85. /
      INTEGER, dimension(ista_2l:iend_2u,jsta_2l:jend_2u) ::  ICBOT, ICTOP, LPBL

!     
!     DECLARE VARIABLES.
!     
!     LOGICAL NORTH,NEED(IM,JM), NMM_GFSmicro
      LOGICAL NMM_GFSmicro
      LOGiCAL Model_Radar
      real, dimension(im,jm)              :: GRID1, GRID2
      real, dimension(ista_2l:iend_2u,jsta_2l:jend_2u) :: EGRID1, EGRID2, EGRID3, EGRID4, EGRID5,&
                                             EL0,    P1D,    T1D,    Q1D,    C1D,   &
                                             FI1D,   FR1D,   FS1D,   QW1,    QI1,   &
                                             QR1,    QS1,    CUREFL_S,              &
                                             CUREFL, CUREFL_I, Zfrz, DBZ1,   DBZR1, &
                                             DBZI1,  DBZC1, EGRID6, EGRID7, NLICE1, &
                                             QI,     QINT,  TT,     PPP,    QV,     &
                                             QCD,    QICE1, QRAIN1, QSNO1,  refl,   &
                                             QG1,    refl1km, refl4km, RH, GUST, NRAIN1,Zm10c, &
                                             USTORE, VSTORE
!                                            T700,   TH700   
!
      REAL, ALLOCATABLE :: EL(:,:,:),RICHNO(:,:,:) ,PBLRI(:,:),  PBLREGIME(:,:)
!
      integer I,J,L,Lctop,LLMH,IICE,LL,II,JJ,IFINCR,ITHEAT,NC,NMOD,LLL  &
             ,iz1km,iz4km, LCOUNT, HCOUNT, ITYPE, item

      real RDTPHS,CFRdum,PMOD,CC1,CC2,P1,P2,CUPRATE,FACR,RRNUM          &
          ,RAINRATE,TERM1,TERM2,TERM3,QROLD,SNORATE,DENS,DELZ,FCTR,HGT  &
          ,rain,ronv,slor,snow,rhoqs,temp_c,sonv,slos                   &
          ,graupel,rhoqg,gonv,slog, alpha, rhod, bb                     &
          ,ze_s, ze_r, ze_g, ze_max, ze_nc, ze_conv, ze_sum             &
          ,ze_smax, ze_rmax,ze_gmax, ze_nc_1km, ze_nc_4km, dz           &
          ,LAPSES, EXPo,EXPINV,TSFCNEW, GAM,GAMD,GAMS, PBLHOLD          &
          ,PSFC,TSFC,ZSFC,DP,DPBND,Zmin

      real, allocatable :: RH3D(:,:,:)

! for PBL smoothing used in GUST
      integer ks,nsmooth
      REAL SDUMMY(IM,2),dxm
! added to calculate cape and cin for icing
      real, dimension(ista:iend,jsta:jend) ::  dummy, cape, cin
      integer idummy(ista:iend,jsta:jend)

      real, PARAMETER :: ZSL=0.0, TAUCR=RD*GI*290.66, CONST=0.005*G/RD, GORD=G/RD
      logical, parameter :: debugprint = .false.

      GAMS = 0.0065
      GAMD = 0.0100

      LAPSES = 0.0065                ! deg K / meter
      EXPo = ROG*LAPSES
      EXPINV = 1./EXPo

      Zmin=10.**(0.1*DBZmin)
!
!     
!*****************************************************************************
!     START SUBROUTINE MDLFLD.
!
!     ALLOCATE LOCAL ARRAYS
!
! Initialize halo regions of USTORE & VSTORE for cases when the halo extends
! beyond the computational domain boundary.
!$OMP PARALLEL DO COLLAPSE(2)
      DO J=jsta_2l,jend_2u
        DO I=ista_2l,iend_2u
          USTORE(I,J) = 0
          VSTORE(I,J) = 0
        ENDDO
      ENDDO
! Set up logical flag to indicate whether model outputs radar directly
      Model_Radar = .false.
!      IF (ABS(MAXVAL(REF_10CM)-SPVAL)>SMALL)Model_Radar=.True.
      check_ref: DO L=1,LM
        DO J=JSTA,JEND
        DO I=ista,iend
          IF(ABS(REF_10CM(I,J,L)-SPVAL)>SMALL) THEN
            Model_Radar=.True.
            exit check_ref
          ENDIF
        ENDDO
        ENDDO
      ENDDO check_ref
      if(debugprint .and. me==0)print*,'Did post read in model derived radar ref ',Model_Radar, &
        'MODELNAME=',trim(MODELNAME),' imp_physics=',imp_physics 
      ALLOCATE(EL     (ista_2l:iend_2u,JSTA_2L:JEND_2U,LM))     
      ALLOCATE(RICHNO (ista_2l:iend_2u,JSTA_2L:JEND_2U,LM))
      ALLOCATE(PBLRI  (ista_2l:iend_2u,JSTA_2L:JEND_2U))    
!     
!     SECOND, STANDARD NGM SEA LEVEL PRESSURE.
      IF (IGET(023) > 0 .OR. IGET(105) > 0 .OR. IGET(445) > 0) THEN
        CALL NGMSLP   ! this value is used in some later calculation.
      ENDIF
      IF (IGET(105) > 0) THEN
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
             DO I=ista,iend
               GRID1(I,J) = SLP(I,J)
             ENDDO
           ENDDO
           if(grib=="grib2") then
             cfld=cfld+1
             fld_info(cfld)%ifld=IAVBLFLD(IGET(105))
!$omp parallel do private(i,j,ii,jj)
             do j=1,jend-jsta+1
               jj = jsta+j-1
               do i=1,iend-ista+1
                 ii = ista+i-1
                 datapd(i,j,cfld) = GRID1(ii,jj)
               enddo
             enddo
           endif
        
      ENDIF
!
!--- Calculate convective cloud fractions following radiation in
!    NMM; used in subroutine CALRAD_WCLOUD for satellite radiances
!Both FV3 regional and global output CNVCFR directly
      IF (MODELNAME=='NMM' .OR. imp_physics==5 .or. &
         imp_physics==85 .or. imp_physics==95) THEN
!        print*,'DTQ2 in MDLFLD= ',DTQ2
        RDTPHS=24.*3.6E6/DTQ2
        DO J=JSTA,JEND
          DO I=ista,iend
          IF ((HBOT(I,J)-HTOP(I,J)) <= 1.0) THEN
            ICBOT(I,J)=0
            ICTOP(I,J)=0
            CNVCFR(I,J)=0.
          ELSE
            ICBOT(I,J)=NINT(HBOT(I,J))
            ICTOP(I,J)=NINT(HTOP(I,J))
            CFRdum=CC(1)
            PMOD=RDTPHS*CPRATE(I,J)       ! mm/day
            IF (PMOD > PPT(1)) THEN
              DO NC=1,10
                IF(PMOD>PPT(NC)) NMOD=NC
              ENDDO
              IF (NMOD >= 10) THEN
                CFRdum=CC(10)
              ELSE
                CC1=CC(NMOD)
                CC2=CC(NMOD+1)
                P1=PPT(NMOD)
                P2=PPT(NMOD+1)
                CFRdum=CC1+(CC2-CC1)*(PMOD-P1)/(P2-P1)
              ENDIF   !--- End IF (NMOD >= 10) ...
              CFRdum=MIN(H1, CFRdum)
            ENDIF     !--- End IF (PMOD > PPT(1)) ...
!            CNVCFR(I,J)=100.*CFRdum
            CNVCFR(I,J)=CFRdum
          ENDIF       !--- End IF (HBOT(I,J)-HTOP(I,J) <= 1.0) ...
          ENDDO       !--- DO I=ista,iend
        ENDDO         !--- DO J=JSTA,JEND
      ENDIF           !-- IF (MODELNAME=='NMM' .OR. imp_physics==5) THEN
!
!--- Set 
      IF (MODELNAME=='NMM' .AND. imp_physics==9) THEN
         NMM_GFSmicro=.TRUE.
      ELSE
         NMM_GFSmicro=.FALSE.
      ENDIF
!
!    Calculate convective radar reflectivity at the surface (CUREFL_S), 
!    and the decrease in reflectivity above the 0C level (CUREFL_I)
!
      IF(imp_physics==5 .or. imp_physics==85 .or. imp_physics==95  &
        .or. NMM_GFSmicro)THEN
       RDTPHS=3.6E6/DTQ2
       DO J=JSTA,JEND
        DO I=ista,iend
          CUPRATE=RDTPHS*CPRATE(I,J)            !--- Cu precip rate, R (mm/h)
!          CUPRATE=CUPPT(I,J)*1000./TRDLW        !--- mm/h
          Zfrz(I,J)=ZMID(I,J,NINT(LMH(I,J)))  !-- Initialize to lowest model level
          DO L=1,NINT(LMH(I,J))               !-- Start from the top, work down
             IF (T(I,J,L) >= TFRZ) THEN
                Zfrz(I,J)=ZMID(I,J,L)         !-- Find highest level where T>0C
                EXIT
             ENDIF
          ENDDO       !--- DO L=1,NINT(LMH(I,J))
!          IF (CUPRATE <= 0. .OR. CUPPT(I,J)<=0.) THEN
          IF (CUPRATE <= 0. .or. htop(i,j)>=spval) THEN ! bug fix, post doesn not use CUPPT 
             CUREFL_S(I,J)=0.
             CUREFL_I(I,J)=0.
          ELSE
             CUREFL_S(I,J)=ZR_A*CUPRATE**ZR_B   !--- Use Z=A*R**B
             Lctop=NINT(HTOP(I,J))              !--- Cu cld top level
!
!--- Assume convective reflectivity (Z, not dBZ) above 0C level decreases
!    with height by two orders of magnitude (20 dBZ) from the 0C level up
!    to cloud top.  If cloud top temperature is above 0C, assume 20 dBZ
!    decrease occurs in the first 1 km above the 0C level.
!
             CUREFL_I(I,J)=-2./MAX( 1000., ZMID(I,J,Lctop)-Zfrz(I,J) )
          ENDIF       !--- IF (CUPRATE <= 0. .OR. CUPPT(I,J)<=0.) THEN
        ENDDO         !--- End DO I
       ENDDO    

!
!--- Calculate each hydrometeor category & GRID-SCALE cloud fraction
!    (Jin, Aug-Oct '01; Ferrier, Feb '02)
!

       if(icount_calmict==0)then  !only call calmict once in multiple grid processing
       DO L=1,LM
        DO J=JSTA,JEND
        DO I=ista,iend
          P1D(I,J)=PMID(I,J,L)
          T1D(I,J)=T(I,J,L)
          Q1D(I,J)=Q(I,J,L)
          C1D(I,J)=CWM(I,J,L)
          FI1D(I,J)=F_ice(I,J,L)
          FR1D(I,J)=F_rain(I,J,L)
          FS1D(I,J)=MAX(H1, F_RimeF(I,J,L))
!
!--- Estimate radar reflectivity factor at level L
!
          CUREFL(I,J)=0.
          IF (CUREFL_S(I,J) > 0.) THEN
             FCTR=0.
             LLMH = NINT(LMH(I,J)) 
             Lctop=NINT(HTOP(I,J))              !--- Cu cld top level
             IF (L>=Lctop .AND. L<=LLMH) THEN
                DELZ=ZMID(I,J,L)-Zfrz(I,J)
                IF (DELZ <= 0.) THEN
                   FCTR=1.        !-- Below the highest freezing level
                ELSE
       !
       !--- Reduce convective radar reflectivity above freezing level
       !
                   FCTR=10.**(CUREFL_I(I,J)*DELZ)
                ENDIF             !-- End IF (DELZ <= 0.)
             ENDIF                !-- End IF (L>=HTOP(I,J) .OR. L<=LLMH)
             CUREFL(I,J)=FCTR*CUREFL_S(I,J)
          ENDIF                   !-- End IF (CUREFL_S(I,J) > 0.)

        ENDDO         !-- End DO I loop
        ENDDO         !-- End DO J loop 
        IF(imp_physics==5 .or. imp_physics==85 .or. imp_physics==95)THEN
  fer_mic: IF (imp_physics==5) THEN
!
!--- Ferrier-Aligo microphysics in the NMMB
!
!--- Determine composition of condensate in terms of cloud water,
!    rain, and ice (cloud ice & precipitation ice) following the
!    *NEWER* the version of the microphysics; radar reflectivity
!    is derived to be consistent with the microphysical assumptions
!
              CALL CALMICT_new(P1D,T1D,Q1D,C1D,FI1D,FR1D,FS1D,CUREFL   &
     &                  ,QW1,QI1,QR1,QS1,DBZ1,DBZR1,DBZI1,DBZC1,NLICE1, NRAIN1)
           IF(MODELNAME == 'NMM' .and. GRIDTYPE=='B')THEN !NMMB
!
!--- Use reflectivity from NMMB model output for Ferrier-Aligo (imp_physics=5),
!    add bogused contribution from parameterized convection (CUREFL), and 
!    estimate reflectivity from rain (DBZR1) & snow/graupel (DBZI1).
!
refl_miss:   IF (Model_Radar) THEN               
                ! - Model output DBZ is present - proceed with calc
                DO J=JSTA,JEND
                DO I=ista,iend
                IF(P1D(I,J)<spval.and.T1D(I,J)<spval.and.Q1D(I,J)<spval)THEN
                  ze_nc=10.**(0.1*REF_10CM(I,J,L))
                  DBZ1(I,J)=10.*LOG10(max(Zmin,(ze_nc+CUREFL(I,J))))
                  DBZR1(I,J)=MIN(DBZR1(I,J), REF_10CM(I,J,L))
                  DBZI1(I,J)=MIN(DBZI1(I,J), REF_10CM(I,J,L))
                  ze_max=MAX(DBZR1(I,J),DBZI1(I,J))
refl_comp:        IF(REF_10CM(I,J,L)>DBZmin .OR. ze_max>DBZmin) THEN
refl_adj:           IF(REF_10CM(I,J,L)<=DBZmin) THEN
                      DBZR1(I,J)=DBZmin
                      DBZI1(I,J)=DBZmin
                    ELSE IF(ze_max<=DBZmin) THEN
                      IF(QR1(I,J)>QS1(I,J)) THEN
                        DBZR1(I,J)=REF_10CM(I,J,L)
                      ELSE IF(QS1(I,J)>QR1(I,J)) THEN
                        DBZI1(I,J)=REF_10CM(I,J,L)
                      ELSE
                        IF(T1D(I,J)>=TFRZ) THEN
                          DBZR1(I,J)=REF_10CM(I,J,L)
                        ELSE
                          DBZI1(I,J)=REF_10CM(I,J,L)
                        ENDIF
                      ENDIF
                    ELSE 
                      ze_nc=10.**(0.1*REF_10CM(I,J,L))
                      ze_r=10.**(0.1*DBZR1(I,J))
                      ze_s=10.**(0.1*DBZI1(I,J))
                      ze_sum=ze_r+ze_s
                      ze_max=ze_nc/ze_sum
                      ze_r=ze_r*ze_max
                      ze_s=ze_s*ze_max
                      DBZR1(I,J)=10.*LOG10(ze_r)
                      DBZI1(I,J)=10.*LOG10(ze_s)
                    ENDIF  refl_adj
                  ENDIF    refl_comp
                ELSE
                      DBZR1(I,J)=DBZmin
                      DBZI1(I,J)=DBZmin
                ENDIF
                ENDDO
                ENDDO
              ELSE
                ! - Model output dBZ is missing 
                IF (ME==0 .AND. L==1) THEN
                  WRITE(6,'(4A,1x,F7.2)') 'WARNING - MDLFLD: REF_10CM NOT ',    &
                                        'IN NMMB OUTPUT. CHECK ',               &
                                        'SOLVER_STATE.TXT FILE. USING ',        &
                                        'REFL OUTPUT FROM CALMICT.'
                ENDIF
              ENDIF refl_miss
           ENDIF
         ELSE  fer_mic
!
!--- Determine composition of condensate in terms of cloud water,
!    rain, and ice (cloud ice & precipitation ice) following the
!    *OLDER* the version of the microphysics; radar reflectivity
!    is derived to be consistent with the microphysical assumptions
!
              CALL CALMICT_old(P1D,T1D,Q1D,C1D,FI1D,FR1D,FS1D,CUREFL   &
     &                  ,QW1,QI1,QR1,QS1,DBZ1,DBZR1,DBZI1,DBZC1,NLICE1, NRAIN1)
           ENDIF  fer_mic

        ELSE
!
!--- This branch is executed if GFS micro (imp_physics=9) is run in the NMM.
!
           DO J=JSTA,JEND
           DO I=ista,iend
           IF(C1D(I,J)<spval.and.FI1D(I,J)<spval)THEN
              QI1(I,J)=C1D(I,J)*FI1D(I,J)
              QW1(I,J)=C1D(I,J)-QI1(I,J)
           ELSE
              QI1(I,J)=D00
              QW1(I,J)=D00
           ENDIF
              QR1(I,J)=D00
              QS1(I,J)=D00
              DBZ1(I,J)=DBZmin
              DBZR1(I,J)=DBZmin
              DBZI1(I,J)=DBZmin
              DBZC1(I,J)=DBZmin
           ENDDO
           ENDDO
        ENDIF
        DO J=JSTA,JEND
        DO I=ista,iend
          LLMH = NINT(LMH(I,J))
          IF (L > LLMH) THEN
            QQW(I,J,L)  = D00
            QQI(I,J,L)  = D00
            QQR(I,J,L)  = D00
            QQS(I,J,L)  = D00
            CFR(I,J,L)  = D00
            DBZ(I,J,L)  = DBZmin
            DBZR(I,J,L) = DBZmin
            DBZI(I,J,L) = DBZmin
            DBZC(I,J,L) = DBZmin
          ELSE
            QQW(I,J,L)   = MAX(D00, QW1(I,J))
            QQI(I,J,L)   = MAX(D00, QI1(I,J))
            QQR(I,J,L)   = MAX(D00, QR1(I,J))
            QQS(I,J,L)   = MAX(D00, QS1(I,J))
            DBZ(I,J,L)   = MAX(DBZmin, DBZ1(I,J))
            DBZR(I,J,L)  = MAX(DBZmin, DBZR1(I,J))
            DBZI(I,J,L)  = MAX(DBZmin, DBZI1(I,J))
            DBZC(I,J,L)  = MAX(DBZmin, DBZC1(I,J))
            NLICE(I,J,L) = MAX(D00, NLICE1(I,J))
            NRAIN(I,J,L) = MAX(D00, NRAIN1(I,J))
          ENDIF       !-- End IF (L > LMH(I,J)) ...
        ENDDO         !-- End DO I loop
        ENDDO         !-- End DO J loop
                                        
       ENDDO           !-- End DO L loop        
       END IF  ! end of icount_calmict
       icount_calmict=icount_calmict+1
       if(debugprint .and. me==0)print*,'debug calmict:icount_calmict= ',icount_calmict
       
! Chuang: add the option to compute individual microphysics species 
! for NMMB+Zhao and NMMB+WSM6 which are two of SREF members. 
! Per communication with Ferrier (July 2012), he has set up these 
! 2 runs to output CWM plus fraction arrays instead of individual 
! microphysics species arrays.
! WRF NMM + non Ferrier still outputs individual microphysics 
! arrays so these 2 if branches are excuted for NMMB only.
      ELSE IF(MODELNAME == 'NMM' .and. GRIDTYPE=='B' .and. imp_physics==99)THEN !NMMB+Zhao
       DO L=1,LM
        DO J=JSTA,JEND
         DO I=ista,iend
          LLMH = NINT(LMH(I,J))
          IF (L > LLMH) THEN
            QQW(I,J,L)  = D00
            QQI(I,J,L)  = D00
            QQR(I,J,L)  = D00
            QQS(I,J,L)  = D00
            CFR(I,J,L)  = D00
            DBZ(I,J,L)  = DBZmin
            DBZR(I,J,L) = DBZmin
            DBZI(I,J,L) = DBZmin
            DBZC(I,J,L) = DBZmin
          ELSE
            QQI(I,J,L)  = MAX(D00, CWM(I,J,L)*F_ice(I,J,L))
            QQW(I,J,L)  = MAX(D00, CWM(I,J,L)-QQI(I,J,L))
            QQR(I,J,L)  = D00
            QQS(I,J,L)  = D00
            DBZ(I,J,L)  = DBZmin
            DBZR(I,J,L) = DBZmin
            DBZI(I,J,L) = DBZmin
            DBZC(I,J,L) = DBZmin
          ENDIF       !-- End IF (L > LMH(I,J)) ...
         ENDDO         !-- End DO I loop
        ENDDO  ! END DO L LOOP
       END DO	
      ELSE IF(MODELNAME == 'NMM' .and. GRIDTYPE=='B' .and. imp_physics==6)THEN !NMMB+WSM6
       DO L=1,LM
        DO J=JSTA,JEND
         DO I=ista,iend
          LLMH = NINT(LMH(I,J))
          IF (L > LLMH) THEN
            QQW(I,J,L)=D00
            QQI(I,J,L)=D00
            QQR(I,J,L)=D00
            QQS(I,J,L)=D00
            CFR(I,J,L)=D00
            DBZ(I,J,L)=DBZmin
            DBZR(I,J,L)=DBZmin
            DBZI(I,J,L)=DBZmin
            DBZC(I,J,L)=DBZmin
          ELSE
            QQI(I,J,L)=D00
	    QQW(I,J,L)=MAX(D00, (1.-F_ice(I,J,L))*CWM(I,J,L)*(1.-F_rain(I,J,L)))
            QQR(I,J,L)=MAX(D00,(1.-F_ice(I,J,L))*CWM(I,J,L)*F_rain(I,J,L))
            QQS(I,J,L)=MAX(D00, CWM(I,J,L)*F_ice(I,J,L))
	    DENS=PMID(I,J,L)/(RD*T(I,J,L)*(Q(I,J,L)*D608+1.0))      ! DENSITY
	    DBZR(I,J,L)=((QQR(I,J,L)*DENS)**1.75)*           &
     &               3.630803E-9 * 1.E18                  ! Z FOR RAIN
            DBZI(I,J,L)= DBZI(I,J,L)+((QQS(I,J,L)*DENS)**1.75)* &
     &               2.18500E-10 * 1.E18                  ! Z FOR SNOW
            DBZ(I,J,L)=DBZR(I,J,L)+DBZI(I,J,L)
	    IF (DBZ(I,J,L)>0.) DBZ(I,J,L)=10.0*LOG10(DBZ(I,J,L)) ! DBZ
            IF (DBZR(I,J,L)>0.)DBZR(I,J,L)=10.0*LOG10(DBZR(I,J,L)) ! DBZ
            IF (DBZI(I,J,L)>0.)      &
     &         DBZI(I,J,L)=10.0*LOG10(DBZI(I,J,L)) ! DBZ
            DBZ(I,J,L)=MAX(DBZmin, DBZ(I,J,L))
            DBZR(I,J,L)=MAX(DBZmin, DBZR(I,J,L))
            DBZI(I,J,L)=MAX(DBZmin, DBZI(I,J,L))
          ENDIF       !-- End IF (L > LMH(I,J)) ...
         ENDDO         !-- End DO I loop
        ENDDO
       END DO  

      ELSE IF(((MODELNAME == 'NMM' .and. GRIDTYPE=='B') .OR. MODELNAME == 'FV3R' &
        .OR. MODELNAME == 'GFS') &
        .and. (imp_physics==8 .or. imp_physics==17 .or. imp_physics==18))THEN !NMMB or FV3R or GFS +THOMPSON
       DO L=1,LM
        DO J=JSTA,JEND
         DO I=ista,iend
            DBZ(I,J,L)=REF_10CM(I,J,L)
         ENDDO
        ENDDO
       ENDDO
      ELSE IF(imp_physics==99 .or. imp_physics==98)THEN ! Zhao MP
       DO L=1,LM
        DO J=JSTA,JEND
         DO I=ista,iend
            DBZ(I,J,L)=SPVAL
         ENDDO
        ENDDO
       ENDDO
      ELSE ! compute radar refl for other than NAM/Ferrier or GFS/Zhao microphysics
        if(debugprint .and. me==0)print*,'calculating radar ref for non-Ferrier/non-Zhao schemes' 
! Determine IICE FLAG
        IF(IMP_PHYSICS == 1 .OR. IMP_PHYSICS == 3)THEN
          IICE = 0
        ELSE
          IICE = 1
        END IF

! Chuang: add convective contribution for all MP schemes
        RDTPHS=3.6E6/DTQ2
        DO J=JSTA,JEND
         DO I=ista,iend
          CUPRATE=RDTPHS*CPRATE(I,J)            !--- Cu precip rate, R (mm/h)
          Zfrz(I,J)=ZMID(I,J,NINT(LMH(I,J)))  !-- Initialize to lowest model level
          DO L=1,NINT(LMH(I,J))               !-- Start from the top, work down
             IF (T(I,J,L) >= TFRZ) THEN
                Zfrz(I,J)=ZMID(I,J,L)         !-- Find highest level where T>0C
                EXIT
             ENDIF
          ENDDO       !--- DO L=1,NINT(LMH(I,J))
!          IF (CUPRATE <= 0. .OR. CUPPT(I,J)<=0.) THEN
          IF (CUPRATE <= 0. .or. htop(i,j)>=spval) THEN ! bug fix, post doesn not use CUPPT
             CUREFL_S(I,J)=0.
             CUREFL_I(I,J)=0.
          ELSE
             CUREFL_S(I,J)=ZR_A*CUPRATE**ZR_B   !--- Use Z=A*R**B
             Lctop=NINT(HTOP(I,J))              !--- Cu cld top level
!
!--- Assume convective reflectivity (Z, not dBZ) above 0C level decreases
!    with height by two orders of magnitude (20 dBZ) from the 0C level up
!    to cloud top.  If cloud top temperature is above 0C, assume 20 dBZ
!    decrease occurs in the first 1 km above the 0C level.
!
             CUREFL_I(I,J)=-2./MAX( 1000., ZMID(I,J,Lctop)-Zfrz(I,J) )
          ENDIF       !--- IF (CUPRATE <= 0. .OR. CUPPT(I,J)<=0.) THEN
         ENDDO         !--- End DO I
        ENDDO

        IF(IMP_PHYSICS /= 8 .AND. IMP_PHYSICS /= 9 .and. IMP_PHYSICS /= 28) THEN
!tgs - non-Thompson schemes
!$omp parallel do private(i,j,l,curefl,fctr,dens,llmh,lctop,delz,ze_nc)
         DO L=1,LM
           DO J=JSTA,JEND
             DO I=ista,iend
!--- Estimate radar reflectivity factor from convection at level L
!
               CUREFL(I,J)=0.
               IF (CUREFL_S(I,J) > 0.) THEN
                FCTR=0.
                LLMH = NINT(LMH(I,J))
                Lctop=NINT(HTOP(I,J))              !--- Cu cld top level
                IF (L>=Lctop .AND. L<=LLMH) THEN
                 DELZ=ZMID(I,J,L)-Zfrz(I,J)
                 IF (DELZ <= 0.) THEN
                   FCTR=1.        !-- Below the highest freezing level
                 ELSE
       !
       !--- Reduce convective radar reflectivity above freezing level
       !
                   FCTR=10.**(CUREFL_I(I,J)*DELZ)
                 ENDIF             !-- End IF (DELZ <= 0.)
                ENDIF                !-- End IF (L>=HTOP(I,J) .OR. L<=LLMH)
                CUREFL(I,J)=FCTR*CUREFL_S(I,J)
                DBZC(I,J,L)=CUREFL(I,J)
               ENDIF                   !-- End IF (CUREFL_S(I,J) > 0.)

             IF(T(I,J,L)<spval) THEN
!              IF(T(I,J,L)  <  1.0E-3) print*,'ZERO T'    
               IF(T(I,J,L)  >  1.0E-3)                            &
     &         DENS = PMID(I,J,L)/(RD*T(I,J,L)*(Q(I,J,L)*D608+1.0))      ! DENSITY

! PATCH to se(1.-FI1D(I,J))*C1D(I,J)*FR1D(I,J)t QQR, QQS, AND QQG to 
!       zeros if they are negative so that post won't abort

               QQR(I,J,L) = max(QQR(I,J,L),0.0)
               QQS(I,J,L) = max(QQS(I,J,L),0.0)        ! jkw
               IF (IICE == 0) THEN
                 IF (T(I,J,L) >= TFRZ) THEN
                   DBZ(I,J,L) = ((QQR(I,J,L)*DENS)**1.75)*         &
     &                          3.630803E-9 * 1.E18                ! Z FOR RAIN
                   DBZR(I,J,L) = DBZ(I,J,L)
                 ELSE
!mptest            DBZ(I,J,L) = ((QQR(I,J,L)*DENS)**1.75)*  &
                   DBZ(I,J,L) = ((QQS(I,J,L)*DENS)**1.75)*         &
     &                          2.18500E-10 * 1.E18                  ! Z FOR SNOW
                   DBZI(I,J,L) = DBZ(I,J,L)
                 ENDIF
               ELSEIF (IICE == 1) THEN
                 DBZI(I,J,L) = 0.
                 QQG(I,J,L)  = max(QQG(I,J,L),0.0)
                 if(QQR(I,J,L) < SPVAL .and. QQR(I,J,L)> 0.0) then
                   DBZR(I,J,L) = ((QQR(I,J,L)*DENS)**1.75) * 3.630803E-9 * 1.E18 ! Z FOR RAIN
                 else
                   DBZR(I,J,L) = 0.
                 endif
                 if(QQS(I,J,L) < SPVAL .and. QQS(I,J,L) > 0.0) then
                   DBZI(I,J,L) =  ((QQS(I,J,L)*DENS)**1.75) * &
     &                                        2.18500E-10 * 1.E18   ! Z FOR SNOW
                 else
                   DBZI(I,J,L) = 0.
                 endif
                 IF (QQG(I,J,L) < SPVAL .and. QQG(I,J,L)> 0.0) then
                   DBZI(I,J,L) =  DBZI(I,J,L) + ((QQG(I,J,L)*DENS)**1.75) * &
     &                                          1.033267E-9 * 1.E18 ! Z FOR GRAUP
                 else
                   DBZI(I,J,L) = DBZI(I,J,L)
                 endif
               IF (Model_Radar) THEN
                 ze_nc=10.**(0.1*REF_10CM(I,J,L))
                 DBZ(I,J,L) = ze_nc+CUREFL(I,J)
               ELSE 
                 DBZ(I,J,L) = DBZR(I,J,L) + DBZI(I,J,L) + CUREFL(I,J)
               END IF
!                IF(L==27.and.QQR(I,J,L)>1.e-4)print*,              &
!                    'sample QQR DEN,DBZ= ',QQR(I,J,L),DENS,DBZ(I,J,L)
               ENDIF
               IF (DBZ(I,J,L)  > 0.) DBZ(I,J,L)  = 10.0*LOG10(DBZ(I,J,L))  ! DBZ
               IF (DBZR(I,J,L) > 0.) DBZR(I,J,L) = 10.0*LOG10(DBZR(I,J,L)) ! DBZ
               IF (DBZI(I,J,L) > 0.) DBZI(I,J,L) = 10.0*LOG10(DBZI(I,J,L)) ! DBZ
               IF (DBZC(I,J,L) > 0.) DBZC(I,J,L) = 10.0*LOG10(DBZC(I,J,L)) ! DBZ
               LLMH = NINT(LMH(I,J))
               IF(L > LLMH) THEN
                 DBZ(I,J,L)  = DBZmin
                 DBZR(I,J,L) = DBZmin
                 DBZI(I,J,L) = DBZmin
                 DBZC(I,J,L) = DBZmin
               ELSE
                 DBZ(I,J,L)  = MAX(DBZmin, DBZ(I,J,L))
                 DBZR(I,J,L) = MAX(DBZmin, DBZR(I,J,L))
                 DBZI(I,J,L) = MAX(DBZmin, DBZI(I,J,L))
                 DBZC(I,J,L) = MAX(DBZmin, DBZC(I,J,L))
               END IF 
             ELSE
                 DBZ(I,J,L)  = DBZmin
                 DBZR(I,J,L) = DBZmin
                 DBZI(I,J,L) = DBZmin
                 DBZC(I,J,L) = DBZmin
             ENDIF !(T(I,J,L)<spval)
             ENDDO
           ENDDO
         ENDDO
!
!tgs
        ELSE
! for Thompson microphisics scheme (option 8), developed at GSD/ESRL
! 13 January 2009
      call paramr       ! compute constants for reflectivity algorithm

      bb = 0.           !  bright band effect - yes or no (0)
      alpha = 0.224 ! = (1000kg/m^3/917kg/m^3)**2)*(0.176/0.930)
!                      1000kg/m^3 is density of liquid water
!                       917kg/m^3 is density of solid ice
!                      0.176 = dielectric factor of ice
!                      0.930 = dielectric factor of liquid water

      ze_smax = -1.E30
      ze_rmax = -1.E30
      ze_gmax = -1.E30

         DO J=JSTA,JEND
          DO I=ista,iend
        refl(i,j) = -10.
        ze_max = -10.

          iz1km = 0
          iz4km = 0

        DO L=1,LM
          LL=LM-L+1
          IF(T(I,J,LL)<spval)THEN
            IF(T(I,J,LL) < 1.0E-3)print*,'ZERO T'
            IF(T(I,J,LL) > 1.0E-3)                            &
             RHOD=PMID(I,J,LL)/                                  &
               (RD*T(I,J,LL)*(Q(I,J,LL)*D608+1.0))      ! DENSITY
             DZ=ZINT(i,j,ll)-ZINT(i,j,lm+1)
!      Particle size distributions and reflectivity
!      ---------------------------------------------
!       Much of this code borrowed from EXMOISG loop 20 to get particle size
!       distributions

!jmb--    Note that SLOR, SLOS and SLOG are inverse slopes!!!! Also,
!          RONV,SONV,GONV, M-P zero intercept values, normalized by
!          max allowable values.

!         Have to set min values of hydrometeors (r1) large enough to avoid
!          underflow problems with log later on.

!   -- rain
              ze_r = 1.e-35
              if (qqr(i,j,ll) >=  1.e-6) then        
              rain = max(r1,qqr(i,j,ll))
              ronv = (const1r*tanh((qr0 - rain)/delqr0) +        &
               const2r)/ron
              SLOR=(RHOd*RAIN/(TOPR*RONV))**0.25
              ze_r = 720.*ronv*ron*slor**7 ! Stoelinga Eq. 2, reflectivity
              endif

!   -- snow
              ze_s = 1.e-35
              if (qqs(i,j,ll) >= 1.e-6) then        
              snow = max(r1,qqs(i,j,ll))
!             New SONV formulation based on Fig. 7, curve_3 of Houze et al 1979
              rhoqs=RHOd*snow
              temp_C = min(-0.001, T(i,j,ll)-273.15)
              sonv = (min(2.0E8, 2.0E6*exp(-0.12*temp_C)))/son
              slos=(rhoqs/(tops*sonv))**0.25
              ze_s = 720.*alpha*sonv*son*slos**7*(dsnow/drain)**2
!               From Stoelinga Eq. 5, reflectivity

!             For bright band, increase reflectivity by factor of 5.28,
!              which is ratio of dielectric factors for water/ice (.930/.176)
              IF (T(i,j,ll) > 273.15)                         &
               ze_s = ze_s*(1. + 4.28*bb)
              endif 

!   -- graupel
              ze_g = 1.e-35
              if (qqg(i,j,ll) >= 1.e-6) then          
              graupel = max(r1,qqg(i,j,ll))
              rhoqg=RHOd*graupel
              gonv=1.
              gonv=const_ng1*(rhoqg**const_ng2)
              gonv = max(1.e4, min(gonv,gon))
              gonv = gonv/gon
              slog=(rhoqg/(topg*gonv))**0.25
              ze_g = 720.*alpha*gonv*gon*slog**7*(dgraupel/drain)**2
!               Stoelinga Eq. 5 applied to graupel

!             For bright band
              IF (t(i,j,ll) > 273.15)                         &
               ze_g = ze_g*(1. + 4.28*bb)
              endif

!   -- total grid scale
              ze_nc = ze_r + ze_s + ze_g

              if (iz1km==0 .and. dz>1000.) then
                 ze_nc_1km = ze_nc
                 iz1km = 1
              end if

              if (iz4km==0 .and. dz>4000.) then
                 ze_nc_4km = ze_nc
                 iz4km = 1
              end if

              ze_rmax = max(ze_r,ze_rmax)
              ze_smax = max(ze_s,ze_smax)
              ze_gmax = max(ze_g,ze_gmax)
!           Reflectivities are in units of m^6/m^3
!            convert to mm^6/m^3 and take log base 10 to get
!            reflectivities in dbZe (decibels).
!            comp_refl_r(j,k) = 10.*LOG10(ze_r*1.E18)
!            comp_refl_s(j,k) = 10.*LOG10(ze_s*1.E18)
!            comp_refl_g(j,k) = 10.*LOG10(ze_g*1.E18)
!           comp_refl_nc(j,k) = 10.*LOG10(ze_nc*1.E18)


!         Total composite reflectivity, including convection, in dbZe
          ze_sum = ze_nc*1.E18  ! + ze_conv
          ze_max = max(ze_max, ze_sum )

             DBZ(i,j,ll) = ze_sum
             DBZR(i,j,ll) = ze_r*1.E18
             DBZI(i,j,ll) = (ze_s+ze_g)*1.E18
           ELSE
             DBZ(i,j,ll)  = DBZmin
             DBZR(i,j,ll) = DBZmin
             DBZI(i,j,ll) = DBZmin
           ENDIF !T(I,J,LL)<spval
           ENDDO
!         parameterized convection
!         -------------------------
!          conv_prate(i,j)  is convective pcpn rate, assumed in mm/h
!         ze_conv = 300.*conv_prate**1.4 ! Units: mm^6/m^3

          RDTPHS=3.6E6/DT
          CUPRATE=RDTPHS*CPRATE(I,J)            !--- Cu precip rate, R (mm/h)

!        ze_conv= max(0.1,300*(4.*CUPRATE)**1.4)
! -- switch to time-step conv precip in RR
        ze_conv= max(0.1,300*(CUPRATE)**1.4)

!  Combine max resolved reflectivity component
!    and sub-grid scale component
!         Total composite reflectivity, including convection, in dbZe
          ze_sum = ze_max  + ze_conv
          refl(i,j)    = 10.*LOG10(ze_sum)
          refl1km(i,j) = 10.*LOG10(ze_nc_1km*1.E18 + ze_conv)
          refl4km(i,j) = 10.*LOG10(ze_nc_4km*1.E18 + ze_conv)

          ENDDO
         ENDDO

       ze_rmax = 10.*log10(ze_rmax*1.e18)
       ze_smax = 10.*log10(ze_smax*1.e18)
       ze_gmax = 10.*log10(ze_gmax*1.e18)

      ENDIF     !tgs endif for Thompson scheme

      END IF
!     
!     OUTPUT/CALCULATE PRESSURE, OMEGA, POTENTIAL TEMPERATURE,
!     DEWPOINT TEMPERATURE, RELATIVE HUMIDITY, AND 
!     ABSOLUTE VORTICITY ON MDL SURFACES.
!     
!
      allocate (RH3D(ista_2l:iend_2u,jsta_2l:jend_2u,lm))
      IF ( (IGET(001)>0).OR.(IGET(077)>0).OR.      &
           (IGET(002)>0).OR.(IGET(003)>0).OR.      &
           (IGET(004)>0).OR.(IGET(005)>0).OR.      &
           (IGET(006)>0).OR.(IGET(083)>0).OR.      &
           (IGET(007)>0).OR.(IGET(008)>0).OR.      &
           (IGET(009)>0).OR.(IGET(010)>0).OR.      &
           (IGET(084)>0).OR.(IGET(011)>0).OR.      &
           (IGET(041)>0).OR.(IGET(124)>0).OR.      &
           (IGET(078)>0).OR.(IGET(079)>0).OR.      &
           (IGET(125)>0).OR.(IGET(145)>0).OR.      &
           (IGET(140)>0).OR.(IGET(040)>0).OR.      &
           (IGET(181)>0).OR.(IGET(182)>0).OR.      &
           (IGET(199)>0).OR.(IGET(185)>0).OR.      &
           (IGET(186)>0).OR.(IGET(187)>0).OR.      &
           (IGET(250)>0).OR.(IGET(252)>0).OR.      &
           (IGET(276)>0).OR.(IGET(277)>0).OR.      &
           (IGET(750)>0).OR.(IGET(751)>0).OR.      &
           (IGET(752)>0).OR.(IGET(754)>0).OR.      &
           (IGET(278)>0).OR.(IGET(264)>0).OR.      &
           (IGET(450)>0).OR.(IGET(480)>0).OR.      &
           (IGET(479)>0).OR.(IGET(481)>0).OR.      &
           (IGET(774)>0).OR.(IGET(747)>0).OR.      &
           (IGET(464)>0).OR.(IGET(467)>0).OR.      &
           (IGET(470)>0).OR.(IGET(476)>0).OR.      &
           (IGET(629)>0).OR.(IGET(630)>0).OR.      &
           (IGET(909)>0).OR.(IGET(737)>0).OR.      &
           (IGET(742)>0).OR.                       &
           (IGET(994)>0).OR.(IGET(995)>0) ) THEN

      DO 190 L=1,LM

!           PRESSURE ON MDL SURFACES.
            IF (IGET(001)>0) THEN
               IF (LVLS(L,IGET(001))>0) THEN
                 LL=LM-L+1
!$omp parallel do private(i,j)
                 DO J=JSTA,JEND
                   DO I=ista,iend
                     GRID1(I,J) = PMID(I,J,LL)
                   ENDDO
                 ENDDO
                 if(grib=="grib2" )then
                   cfld=cfld+1
                   fld_info(cfld)%ifld=IAVBLFLD(IGET(001))
                   fld_info(cfld)%lvl=LVLSXML(L,IGET(001))
!$omp parallel do private(i,j,ii,jj)
                   do j=1,jend-jsta+1
                     jj = jsta+j-1
                     do i=1,iend-ista+1
                       ii = ista+i-1
                       datapd(i,j,cfld) = GRID1(ii,jj)
                     enddo
                   enddo
                endif
               ENDIF
            ENDIF
!     
!
!---  CLOUD WATER on MDL SURFACE  (Jin, '01; Ferrier, Feb '02)
!
          IF (IGET(124) > 0) THEN
            IF (LVLS(L,IGET(124)) > 0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = QQW(I,J,LL)
                   if(GRID1(I,J)<1e-20) GRID1(I,J) = 0.0
                 ENDDO
               ENDDO    
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(124))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(124))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF 
!
!---  CLOUD ICE ON MDL SURFACE  (Jin, '01; Ferrier, Feb '02)
!
          IF (IGET(125) > 0) THEN
            IF (LVLS(L,IGET(125)) > 0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = QQI(I,J,LL)
                   if(GRID1(I,J)<1e-20) GRID1(I,J) = 0.0
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(125))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(125))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  RAIN ON MDL SURFACE  (Jin, '01; Ferrier, Feb '02)
!
          IF (IGET(181) > 0) THEN
            IF (LVLS(L,IGET(181)) > 0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = QQR(I,J,LL)
                   if(GRID1(I,J)<1e-20) GRID1(I,J) = 0.0
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(181))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(181))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  SNOW ON MDL SURFACE  (Jin, '01; Ferrier, Feb '02)
!
          IF (IGET(182) > 0) THEN
            IF (LVLS(L,IGET(182)) > 0)THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = QQS(I,J,LL)
                   if(GRID1(I,J)<1e-20) GRID1(I,J) = 0.0
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(182))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(182))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  GRAUPEL ON MDL SURFACE   --tgs
!
          IF (IGET(415) > 0) THEN
            IF (LVLS(L,IGET(415)) > 0)THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   if(QQG(I,J,LL) < 1.e-12) QQG(I,J,LL) = 0.     !tgs
                      GRID1(I,J) = QQG(I,J,LL)
                 ENDDO
               ENDDO    
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(415))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(415))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  QNCLOUD ON MDL SURFACE   --cra
!
          IF (IGET(747) > 0) THEN 
            IF (LVLS(L,IGET(747)) > 0)THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   if(QQNW(I,J,LL) < 1.e-8) QQNW(I,J,LL) = 0.     !tgs 
                      GRID1(I,J) = QQNW(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(747))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(747))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  QNICE ON MDL SURFACE   --tgs
!
          IF (IGET(752) > 0) THEN
            IF (LVLS(L,IGET(752)) > 0)THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   if(QQNI(I,J,LL) < 1.e-8) QQNI(I,J,LL) = 0.     !tgs
                      GRID1(I,J) = QQNI(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(752))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(752))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  QNRAIN ON MDL SURFACE   --tgs
!
          IF (IGET(754) > 0) THEN
            IF (LVLS(L,IGET(754)) > 0)THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   if(QQNR(I,J,LL) < 1.e-8) QQNR(I,J,LL) = 0.     !tgs
                   GRID1(I,J) = QQNR(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(754))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(754))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
! QNWFA ON MDL SURFACE   --tgs
!
          IF (IGET(766) > 0) THEN
            IF (LVLS(L,IGET(766)) > 0)THEN
               LL=LM-L+1
               DO J=JSTA,JEND
               DO I=ista,iend
            if(QQNWFA(I,J,LL)<1.e-8)QQNWFA(I,J,LL)=0.     !tgs
                 GRID1(I,J)=QQNWFA(I,J,LL)
               ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(766))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(766))
                 datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
               endif
            ENDIF
          ENDIF
!
!---  QNIFA ON MDL SURFACE   --tgs
!
          IF (IGET(767) > 0) THEN
            IF (LVLS(L,IGET(767)) > 0)THEN
               LL=LM-L+1
               DO J=JSTA,JEND
               DO I=ista,iend
            if(QQNIFA(I,J,LL)<1.e-8)QQNIFA(I,J,LL)=0.     !tgs
                 GRID1(I,J)=QQNIFA(I,J,LL)
               ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(767))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(767))
                 datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
               endif
            ENDIF
          ENDIF
!
!---  Total cloud fraction on MDL surfaces.  (Ferrier, Nov '04)
!
          IF (IGET(145) > 0) THEN
            IF (LVLS(L,IGET(145)) > 0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   IF(abs(CFR(I,J,LL)-SPVAL) > SMALL) THEN
                       GRID1(I,J) = CFR(I,J,LL)*H100
                   ELSE
                       GRID1(I,J) = SPVAL
                   ENDIF
                 ENDDO
               ENDDO
               CALL BOUND(GRID1,D00,H100)
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(145))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(145))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF

!---  Model-state cloud fraction (unprocessed) on model surfaces (JSK, 8 Jan 2015)
!
          IF (IGET(774) > 0) THEN
            IF (LVLS(L,IGET(774)) > 0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   IF(MODELNAME == 'RAPR') THEN
                     GRID1(I,J) = CFR(I,J,LL)
                   ELSE
                     GRID1(I,J) = CFR_RAW(I,J,LL)
                   ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(774))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(774))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF

!---  Equivalent radar reflectivity factor.  
!
          IF (IGET(250) > 0) THEN
            IF (LVLS(L,IGET(250)) > 0) THEN
               LL=LM-L+1

!
! CRA Use WRF Thompson reflectivity diagnostic from RAPR model output
!     Use unipost reflectivity diagnostic otherwise
!
! Chuang Feb 2015: use Thompson reflectivity direct output for all
! models 
! 
               IF(IMP_PHYSICS == 8 .or. IMP_PHYSICS == 28) THEN
!$omp parallel do private(i,j)
                 DO J=JSTA,JEND
                   DO I=ista,iend
                     GRID1(I,J) = REF_10CM(I,J,LL)
                   ENDDO
                 ENDDO
               ELSE
!$omp parallel do private(i,j)
                 DO J=JSTA,JEND
                   DO I=ista,iend
                     GRID1(I,J) = DBZ(I,J,LL)
                   ENDDO
                 ENDDO
               ENDIF
! CRA
               CALL BOUND(GRID1,DBZmin,DBZmax)
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(250))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(250))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF

!
!--- TOTAL CONDENSATE ON MDL SURFACE (CWM array; Ferrier, Feb '02)
!
          IF (IGET(199)>0) THEN
            IF (LVLS(L,IGET(199))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = CWM(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(199))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(199))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  F_rain ON MDL SURFACE  (Jin, '01; Ferrier, Feb '02)
!
          IF (IGET(185)>0) THEN
            IF (LVLS(L,IGET(185))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = F_rain(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(185))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(185))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  F_ice ON MDL SURFACE  (Jin, '01; Ferrier, Feb '02)
!
          IF (IGET(186)>0) THEN
            IF (LVLS(L,IGET(186))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = F_ice(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(186))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(186))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            ENDIF
          ENDIF
!
!---  F_RimeF ON MDL SURFACE  (Jin, '01; Ferrier, Feb '02)
!
          IF (IGET(187)>0) THEN
            IF (LVLS(L,IGET(187))>0) THEN
!--- Filter "rime factor" for non-zero precip rates and % frozen precip
              LL=LM-L+1
!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                 GRID1(I,J) = F_RimeF(I,J,LL)
                ENDDO
              ENDDO
              if(grib=="grib2" )then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(187))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(187))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
              endif
            ENDIF

          ENDIF
!	  
!           HEIGHTS ON MDL SURFACES.
            IF (IGET(077)>0) THEN
             IF (LVLS(L,IGET(077))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = ZMID(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(077))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(077))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             ENDIF

            ENDIF
!     
!           TEMPERATURE ON MDL SURFACES.
            IF (IGET(002)>0) THEN
              IF (LVLS(L,IGET(002))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = T(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(002))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(002))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
              ENDIF

            ENDIF

!           VIRTUAL TEMPERATURE ON MDL SURFACES.
            IF (IGET(909)>0) THEN
              IF (LVLS(L,IGET(909))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(T(I,J,LL)<spval.and.Q(I,J,LL)<spval)THEN
                   GRID1(I,J)=T(I,J,LL)*(1.+D608*Q(I,J,LL))
                 ELSE
                   GRID1(I,J)=spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(909))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(909))
                 datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
               endif
              ENDIF

            ENDIF
!     
!           POTENTIAL TEMPERATURE ON MDL SURFACES.
            IF (IGET(003)>0) THEN
              IF (LVLS(L,IGET(003))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   P1D(I,J) = PMID(I,J,LL)
                   T1D(I,J) = T(I,J,LL)
                 ENDDO
               ENDDO
               CALL CALPOT(P1D(ista:iend,jsta:jend),T1D(ista:iend,jsta:jend),EGRID3(ista:iend,jsta:jend))

!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = EGRID3(I,J)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(003))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(003))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                    ii = ista+i-1
                    datapd(i,j,cfld) = GRID1(ii,jj)
                  enddo
                enddo
               endif
!
             ENDIF
            ENDIF
!     
!           VIRTUAL POTENTIAL TEMPERATURE ON MDL SURFACES.
            IF (IGET(751)>0) THEN
             IF (LVLS(L,IGET(751))>0) THEN
              LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   P1D(I,J) = PMID(I,J,LL)
                   T1D(I,J) = T(I,J,LL)
                 ENDDO
               ENDDO
               CALL CALPOT(P1D(ista:iend,jsta:jend),T1D(ista:iend,jsta:jend),EGRID3(ista:iend,jsta:jend))

!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(P1D(I,J)<spval.and.T1D(I,J)<spval.and.Q(I,J,LL)<spval)THEN
                   GRID1(I,J) = EGRID3(I,J) * (1.+D608*Q(I,J,LL))
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(751))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(751))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                    ii = ista+i-1
                    datapd(i,j,cfld) = GRID1(ii,jj)
                  enddo
                enddo
               endif
             ENDIF
            ENDIF

!
!           RELATIVE HUMIDITY ON MDL SURFACES.
            item = -1
            IF (IGET(006) > 0) item = LVLS(L,IGET(006))
            IF (item > 0 .OR. IGET(450) > 0 .OR. IGET(480) > 0 .OR. &
                IGET(479) > 0 .OR. IGET(481) > 0 ) THEN
              LL=LM-L+1
!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                  P1D(I,J) = PMID(I,J,LL)
                  T1D(I,J) = T(I,J,LL)
                  Q1D(I,J) = Q(I,J,LL)
                ENDDO
              ENDDO

            CALL CALRH(P1D(ista:iend,jsta:jend),T1D(ista:iend,jsta:jend),Q1D(ista:iend,jsta:jend),EGRID4(ista:iend,jsta:jend))

!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                IF(P1D(I,J)<spval.and.T1D(I,J)<spval.and.Q1D(I,J)<spval)THEN
                  GRID1(I,J)   = EGRID4(I,J)*100.
                  RH3D(I,J,LL) = GRID1(I,J)
                  EGRID2(I,J)  = Q(I,J,LL)/max(1.e-8,EGRID4(I,J)) ! Revert QS to compute cloud cover later
                ELSE
                  GRID1(I,J)   = spval
                  RH3D(I,J,LL) = spval
                  EGRID2(I,J)  = spval
                ENDIF
                ENDDO
              ENDDO
              IF (item > 0) then
                if(grib=="grib2") then
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(006))
                  fld_info(cfld)%lvl=LVLSXML(L,IGET(006))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                    jj = jsta+j-1
                    do i=1,iend-ista+1
                      ii = ista+i-1
                      datapd(i,j,cfld) = GRID1(ii,jj)
                    enddo
                  enddo
                endif
              ENDIF
            ENDIF

!     
!           DEWPOINT ON MDL SURFACES.
            IF (IGET(004)>0) THEN
             IF (LVLS(L,IGET(004))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   P1D(I,J) = PMID(I,J,LL)
                   T1D(I,J) = T(I,J,LL)
                   Q1D(I,J) = Q(I,J,LL)
                 ENDDO
               ENDDO
               CALL CALDWP(P1D(ista:iend,jsta:jend),Q1D(ista:iend,jsta:jend),EGRID3(ista:iend,jsta:jend),T1D(ista:iend,jsta:jend))
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(P1D(I,J)<spval.and.T1D(I,J)<spval.and.Q1D(I,J)<spval)THEN
                   GRID1(I,J) = EGRID3(I,J)
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(004))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(004))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             ENDIF
            ENDIF
!     
!           SPECIFIC HUMIDITY ON MDL SURFACES.
            IF (IGET(005)>0) THEN
             IF (LVLS(L,IGET(005))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = Q(I,J,LL)
                 ENDDO
               ENDDO
               CALL BOUND(GRID1,H1M12,H99999)
              if(grib=="grib2") then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(005))
               fld_info(cfld)%lvl=LVLSXML(L,IGET(005))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                   ii = ista+i-1
                   datapd(i,j,cfld) = GRID1(ii,jj)
                 enddo
               enddo
              endif
             ENDIF
            ENDIF
!     
!           WATER VAPOR MIXING RATIO ON MDL SURFACES.
            IF (IGET(750)>0) THEN
             IF (LVLS(L,IGET(750))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(Q(I,J,LL)<spval)THEN
                   GRID1(I,J) = Q(I,J,LL) / (1.-Q(I,J,LL))
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               CALL BOUND(GRID1,H1M12,H99999)
               if(grib=="grib2") then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(750))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(750))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                    ii = ista+i-1
                    datapd(i,j,cfld) = GRID1(ii,jj)
                  enddo
                enddo
               endif
             ENDIF
            ENDIF
!     
!           MOISTURE CONVERGENCE ON MDL SURFACES.
            LLL = 0
            if (IGET(083) > 0) LLL = LVLS(L,IGET(083))
            IF (IGET(083)>0 .OR. IGET(295)>0) THEN
             IF (LLL >0 .OR. IGET(295)>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA_2L,JEND_2U
                 DO I=ista_2l,iend_2u
                   Q1D(I,J)    = Q(I,J,LL)
                   EGRID1(I,J) = UH(I,J,LL)
                   EGRID2(I,J) = VH(I,J,LL)
                 ENDDO
               ENDDO
               CALL CALMCVG(Q1D,EGRID1,EGRID2,EGRID3)
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(Q1D(I,J)<spval.and.EGRID1(I,J)<spval.and.EGRID2(I,J)<spval)THEN
                   GRID1(I,J)   = EGRID3(I,J)
                   MCVG(I,J,LL) = EGRID3(I,J)
                 ELSE
                   GRID1(I,J)   = spval
                   MCVG(I,J,LL) = spval
                 ENDIF
                 ENDDO
               ENDDO
               IF(IGET(083)>0 .AND. LLL>0)THEN
                if(grib=="grib2") then
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(083))
                  fld_info(cfld)%lvl=LVLSXML(L,IGET(083))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                    jj = jsta+j-1
                    do i=1,iend-ista+1
                      ii = ista+i-1
                      datapd(i,j,cfld) = GRID1(ii,jj)
                    enddo
                  enddo
                endif
               ENDIF
             ENDIF
            ENDIF
!     
!           U AND/OR V WIND ON MDL SURFACES.
!MEB needs to be modified to do u at u-points and v at v-points
            IF (IGET(007)>0.OR.IGET(008)>0) THEN
             IF (LVLS(L,IGET(007))>0.OR.LVLS(L,IGET(008))>0 ) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = UH(I,J,LL)
                   GRID2(I,J) = VH(I,J,LL)
                 ENDDO
               ENDDO
              if(grib=="grib2") then
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(007))
               fld_info(cfld)%lvl=LVLSXML(L,IGET(007))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                   ii = ista+i-1
                   datapd(i,j,cfld) = GRID1(ii,jj)
                 enddo
               enddo
               cfld=cfld+1
               fld_info(cfld)%ifld=IAVBLFLD(IGET(008))
               fld_info(cfld)%lvl=LVLSXML(L,IGET(008))
!$omp parallel do private(i,j,ii,jj)
               do j=1,jend-jsta+1
                 jj = jsta+j-1
                 do i=1,iend-ista+1
                   ii = ista+i-1
                   datapd(i,j,cfld) = GRID2(ii,jj)
                 enddo
               enddo
              endif
             ENDIF
            ENDIF
!     
!           OMEGA ON MDL SURFACES.
            IF (IGET(009)>0) THEN
             IF (LVLS(L,IGET(009))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = OMGA(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(009))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(009))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             ENDIF
            ENDIF
!     
!           W ON MDL SURFACES.
            IF (IGET(264)>0) THEN
             IF (LVLS(L,IGET(264))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J)=WH(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(264))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(264))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             ENDIF
            ENDIF
!     
!           ABSOLUTE VORTICITY ON MDL SURFACES.
            IF (IGET(010)>0) THEN
             IF (LVLS(L,IGET(010))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA_2L,JEND_2U
                 DO I=ista_2l,iend_2u
                   EGRID1(I,J) = UH(I,J,LL)
                   EGRID2(I,J) = VH(I,J,LL)
                 ENDDO
               ENDDO
               CALL CALVOR(EGRID1,EGRID2,EGRID3)
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(EGRID3(I,J)<spval)THEN
                   GRID1(I,J) = EGRID3(I,J)
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(010))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(010))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             ENDIF
            ENDIF
!     
!           GEOSTROPHIC STREAMFUNCTION ON MDL SURFACES.
            IF (IGET(084)>0) THEN
             IF (LVLS(L,IGET(084))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   EGRID1(I,J) = ZMID(I,J,LL)
                 ENDDO
               ENDDO
               CALL CALSTRM(EGRID1(ista:iend,jsta:jend),EGRID2(ista:iend,jsta:jend))
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = EGRID2(I,J)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(084))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(084))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             ENDIF
            ENDIF
!     
!           TURBULENT KINETIC ENERGY ON MDL SURFACES.
            IF (IGET(011)>0) THEN
               IF (LVLS(L,IGET(011))>0) THEN
                 LL=LM-L+1
!$omp parallel do private(i,j)
                DO J=JSTA,JEND
                  DO I=ista,iend
                    GRID1(I,J) = Q2(I,J,LL)
                  ENDDO
                ENDDO
                if(grib=="grib2") then
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(011))
                  fld_info(cfld)%lvl=LVLSXML(L,IGET(011))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                    jj = jsta+j-1
                    do i=1,iend-ista+1
                      ii = ista+i-1
                      datapd(i,j,cfld) = GRID1(ii,jj)
                    enddo
                  enddo
               endif
               ENDIF
            ENDIF
!    
!           CLOUD WATER CONTENT
!HC            IF (IGET(124)>0) THEN
!HC             IF (LVLS(L,IGET(124))>0) THEN
!HC              DO J=JSTA,JEND
!HC              DO I=ista,iend
!HC                IF(CWM(I,J,L)<0..AND.CWM(I,J,L)>-1.E-10)
!HC     1            CWM(I,J,L)=0.
!HC                 GRID1(I,J)=CWM(I,J,L)
!HC              ENDDO
!HC              ENDDO
!HC              ID(1:25) = 0
!HC              CALL GRIBIT(IGET(124),L,GRIDista,iend,JM)
!HC             ENDIF
!HC            ENDIF
!     
!           CLOUD ICE CONTENT.
!commented out until QICE is brought into post
!           IF (IGET(125)>0) THEN
!            IF (LVLS(L,IGET(125))>0) THEN
!              DO J=JSTA,JEND
!              DO I=ista,iend
!                GRID1(I,J)=QICE(I,J,L)
!              ENDDO
!              ENDDO
!              ID(1:25) = 0
!              CALL GRIBIT(IGET(125),L,GRIDista,iend,JM)
!            ENDIF
!           ENDIF
!     
!           CLOUD FRACTION
!     
!commented out until CFRC is brought into post
!           IF (IGET(145)>0) THEN
!            IF (LVLS(L,IGET(145))>0) THEN
!              DO J=JSTA,JEND
!              DO I=ista,iend
!                GRID1(I,J)=CFRC(I,J,L)
!              ENDDO
!              ENDDO
!              ID(1:25) = 0
!              CALL GRIBIT(IGET(145),L,GRIDista,iend,JM)
!            ENDIF
!           ENDIF
!     
!           TEMPERATURE TENDENCY DUE TO RADIATIVE FLUX CONVERGENCE
!commented out until TTND is brought into post
           IF (IGET(140)>0) THEN
             IF (LVLS(L,IGET(140))>0) THEN
              LL=LM-L+1
!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                  GRID1(I,J) = TTND(I,J,LL)
                ENDDO
              ENDDO
              if(grib=="grib2") then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(140))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(140))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                    ii = ista+i-1
                    datapd(i,j,cfld) = GRID1(ii,jj)
                  enddo
                enddo
              endif
             ENDIF
           ENDIF
!     
!           TEMPERATURE TENDENCY DUE TO SHORT WAVE RADIATION.
!commented out until RSWTT is brought into post
           IF (IGET(040)>0) THEN
            IF (LVLS(L,IGET(040))>0) THEN
              LL=LM-L+1
!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                  GRID1(I,J) = RSWTT(I,J,LL)
                ENDDO
              ENDDO
              if(grib=="grib2") then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(040))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(040))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                    ii = ista+i-1
                    datapd(i,j,cfld) = GRID1(ii,jj)
                  enddo
                enddo
              endif
            ENDIF
           ENDIF
!     
!           TEMPERATURE TENDENCY DUE TO LONG WAVE RADIATION.
!commented out until RLWTT is brought into post
           IF (IGET(041)>0) THEN
             IF (LVLS(L,IGET(041))>0) THEN
              LL=LM-L+1
!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                  GRID1(I,J) = RLWTT(I,J,LL)
                ENDDO
              ENDDO
              if(grib=="grib2") then
                cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(041))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(041))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                    ii = ista+i-1
                    datapd(i,j,cfld) = GRID1(ii,jj)
                  enddo
                enddo
              endif
             ENDIF
           ENDIF
!
!     
!        PROCESS NEXT MDL LEVEL.
!
!           LATENT HEATING FROM GRID SCALE RAIN/EVAP. (TIME AVE)
           IF (IGET(078)>0) THEN
             IF (LVLS(L,IGET(078))>0) THEN
               LL=LM-L+1 
               IF(AVRAIN>0.)THEN 
                 RRNUM=1./AVRAIN
               ELSE
                 RRNUM=0.
               ENDIF
!$omp  parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(TRAIN(I,J,LL)<spval)THEN
                   GRID1(I,J) = TRAIN(I,J,LL)*RRNUM
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               ID(1:25) = 0
               ITHEAT     = INT(THEAT)
	       IF (ITHEAT /= 0) THEN
                IFINCR     = MOD(IFHR,ITHEAT)
	       ELSE
	        IFINCR=0
	       END IF
               ID(19) = IFHR
	       IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
               ID(20) = 3
               IF (IFINCR==0) THEN
                  ID(18) = IFHR-ITHEAT
               ELSE
                  ID(18) = IFHR-IFINCR
               ENDIF
               IF(IFMIN >= 1)ID(18)=ID(18)*60
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(078))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(078))
                 if(ITHEAT==0) then
                   fld_info(cfld)%ntrange=0
                 else
                   fld_info(cfld)%ntrange=1
                 endif
                 fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            END IF
           ENDIF
!
!           LATENT HEATING FROM CONVECTION. (TIME AVE)
           IF (IGET(079)>0) THEN
            IF (LVLS(L,IGET(079))>0) THEN
               LL=LM-L+1 
               IF(AVCNVC>0.)THEN
                 RRNUM=1./AVCNVC
               ELSE
                 RRNUM=0.
               ENDIF
!$omp  parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(TCUCN(I,J,LL)<spval)THEN
                   GRID1(I,J) = TCUCN(I,J,LL)*RRNUM
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               ID(1:25) = 0
               ITHEAT     = INT(THEAT)
	       IF (ITHEAT /= 0) THEN
                IFINCR     = MOD(IFHR,ITHEAT)
	       ELSE
	        IFINCR=0
	       END IF
               ID(19) = IFHR
	       IF(IFMIN >= 1)ID(19)=IFHR*60+IFMIN
               ID(20) = 3
               IF (IFINCR==0) THEN
                  ID(18) = IFHR-ITHEAT
               ELSE
                  ID(18) = IFHR-IFINCR
               ENDIF
               IF(IFMIN >= 1)ID(18)=ID(18)*60
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(079))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(079))
                 if(ITHEAT==0) then
                   fld_info(cfld)%ntrange=0
                 else
                   fld_info(cfld)%ntrange=1
                 endif
                 fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            END IF
           ENDIF
!
!           OZONE
           IF (IGET(267)>0) THEN
             IF (LVLS(L,IGET(267))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = O3(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(267))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(267))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            END IF
           ENDIF

!===============
! AQF
!===============

        if (aqf_on) then

           IF (IGET(994)>0) THEN
             IF (LVLS(L,IGET(994))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ISTA,IEND
                   IF(AVGOZCON(I,J,LL)<SPVAL) THEN
                   GRID1(I,J) = AVGOZCON(I,J,LL)    ! in ppb
                   ELSE
                   GRID1(I,J) = SPVAL
                   ENDIF
                 ENDDO
               ENDDO
               ID(1:25) = 0
               ITHEAT     = INT(THEAT)
               ID(19) = IFHR
               ID(20) = 3
               IF (IFHR==0) THEN
                  ID(18) = 0
               ELSE
                  ID(18) = IFHR-1
               ENDIF
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(994))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(994))
                 if(IFHR==0) then
                   fld_info(cfld)%ntrange=0
                 else
                   fld_info(cfld)%ntrange=1
                 endif
                 fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                   ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            END IF
           ENDIF


        !---- PM25 ----

           IF (IGET(995)>0) THEN
             IF (LVLS(L,IGET(995))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ISTA,IEND
                   GRID1(I,J) = AVGPMTF(I,J,LL)      !ug/m3
                 ENDDO
               ENDDO
               ID(1:25) = 0
               ITHEAT     = INT(THEAT)
               ID(19) = IFHR
               ID(20) = 3
               IF (IFHR==0) THEN
                  ID(18) = 0
               ELSE
                  ID(18) = IFHR-1
               ENDIF
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(995))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(995))
                 if(IFHR==0) then
                   fld_info(cfld)%ntrange=0
                 else
                   fld_info(cfld)%ntrange=1
                 endif
                 fld_info(cfld)%tinvstat=IFHR-ID(18)
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                   ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
            END IF
           ENDIF

        endif    ! -- aqfcmaq_on

!===================================

!
! E. James - 8 Dec 2017: SMOKE from WRF-CHEM
!          SMOKE
           IF (IGET(737)>0) THEN
             IF (LVLS(L,IGET(737))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
               DO I=ista,iend
               IF(PMID(I,J,LL)<spval.and.T(I,J,LL)<spval.and.SMOKE(I,J,LL,1)<spval)THEN
                 GRID1(I,J) = (1./RD)*(PMID(I,J,LL)/T(I,J,LL))*SMOKE(I,J,LL,1)/(1E9)
               ELSE
                 GRID1(I,J) = spval
               ENDIF
               ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(737))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(737))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF
! E. James - 14 Sep 2022: Dust from RRFS
!          DUST
           IF (IGET(742)>0) THEN
             IF (LVLS(L,IGET(742))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
               DO I=ista,iend
               IF(PMID(I,J,LL)<spval.and.T(I,J,LL)<spval.and.FV3DUST(I,J,LL,1)<spval)THEN
                 GRID1(I,J) = (1./RD)*(PMID(I,J,LL)/T(I,J,LL))*FV3DUST(I,J,LL,1)/(1E9)
               ELSE
                 GRID1(I,J) = spval
               ENDIF
               ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(742))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(742))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF
! E. James - 23 Feb 2023: COARSEPM from RRFS
!          DUST
           IF (IGET(1012)>0) THEN
             IF (LVLS(L,IGET(1012))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
               DO I=ista,iend
               IF(PMID(I,J,LL)<spval.and.T(I,J,LL)<spval.and.COARSEPM(I,J,LL,1)<spval)THEN
                 GRID1(I,J) = (1./RD)*(PMID(I,J,LL)/T(I,J,LL))*COARSEPM(I,J,LL,1)/(1E9)
               ELSE
                 GRID1(I,J) = spval
               ENDIF
               ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(1012))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(1012))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF
!
       if ( gocart_on .or. gccpp_on .or. nasa_on ) then
!          DUST 1
           IF (IGET(629)>0) THEN
             IF (LVLS(L,IGET(629))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
               DO I=ista,iend
               IF(DUST(I,J,LL,1)<spval.and.RHOMID(I,J,LL)<spval)THEN
                 !GRID1(I,J) = DUST(I,J,LL,1)
                 GRID1(I,J) = DUST(I,J,LL,1)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
               ELSE
                 GRID1(I,J) = spval
               ENDIF               
               ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(629))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(629))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          DUST 2
           IF (IGET(630)>0) THEN
             IF (LVLS(L,IGET(630))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
               DO I=ista,iend
               IF(DUST(I,J,LL,2)<spval.and.RHOMID(I,J,LL)<spval)THEN
                 !GRID1(I,J) = DUST(I,J,LL,2)
                 GRID1(I,J) = DUST(I,J,LL,2)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
               ELSE
                 GRID1(I,J) = spval
               ENDIF
               ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(630))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(630))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          DUST 3
           IF (IGET(631)>0) THEN
             IF (LVLS(L,IGET(631))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(DUST(I,J,LL,3)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   !GRID1(I,J) = DUST(I,J,LL,3)
                   GRID1(I,J) = DUST(I,J,LL,3)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
               ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(631))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(631))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          DUST 4
           IF (IGET(632)>0) THEN
             IF (LVLS(L,IGET(632))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(DUST(I,J,LL,4)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   !GRID1(I,J) = DUST(I,J,LL,4)
                   GRID1(I,J) = DUST(I,J,LL,4)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(632))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(632))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          DUST 5
           IF (IGET(633)>0) THEN
             IF (LVLS(L,IGET(633))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(DUST(I,J,LL,5)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   !GRID1(I,J) = DUST(I,J,LL,5)
                   GRID1(I,J) = DUST(I,J,LL,5)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(633))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(633))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          SEASALT 1 
           IF (IGET(634)>0) THEN
             IF (LVLS(L,IGET(634))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(SALT(I,J,LL,1)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   GRID1(I,J) = SALT(I,J,LL,1)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(634))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(634))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          SEASALT 2 
           IF (IGET(635)>0) THEN
             IF (LVLS(L,IGET(635))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(SALT(I,J,LL,2)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   GRID1(I,J) = SALT(I,J,LL,2)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(635))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(635))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          SEASALT 3 
           IF (IGET(636)>0) THEN
             IF (LVLS(L,IGET(636))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(SALT(I,J,LL,3)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   GRID1(I,J) = SALT(I,J,LL,3)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(636))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(636))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          SEASALT 4 
           IF (IGET(637)>0) THEN
             IF (LVLS(L,IGET(637))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(SALT(I,J,LL,4)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   GRID1(I,J) = SALT(I,J,LL,4)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(637))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(637))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          SEASALT 0
           IF (IGET(638)>0) THEN
             IF (LVLS(L,IGET(638))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(SALT(I,J,LL,5)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   GRID1(I,J) = SALT(I,J,LL,5)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(638))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(638))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          SULFATE 
           IF (IGET(639)>0) THEN
             IF (LVLS(L,IGET(639))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(SUSO(I,J,LL,1)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   !GRID1(I,J) = SUSO(I,J,LL,1)
                   GRID1(I,J) = SUSO(I,J,LL,1)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(639))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(639))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          OC DRY (HYDROPHOBIC ORGANIC CARBON)
           IF (IGET(640)>0) THEN
             IF (LVLS(L,IGET(640))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(WASO(I,J,LL,1)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   !GRID1(I,J) = WASO(I,J,LL,1)
                   GRID1(I,J) = WASO(I,J,LL,1)*RHOMID(I,J,LL) !lzhang
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(640))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(640))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          OC WET (HYDROPHILIC ORGANIC CARBON)
           IF (IGET(641)>0) THEN
             IF (LVLS(L,IGET(641))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(WASO(I,J,LL,2)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   !GRID1(I,J) = WASO(I,J,LL,2)
                   GRID1(I,J) = WASO(I,J,LL,2)*RHOMID(I,J,LL) !lzhang
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(641))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(641))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          BC DRY (HYDROPHOBIC BLACK CARBON)
           IF (IGET(642)>0) THEN
             IF (LVLS(L,IGET(642))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(SOOT(I,J,LL,1)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   !GRID1(I,J) = SOOT(I,J,LL,1)
                   GRID1(I,J) = SOOT(I,J,LL,1)*RHOMID(I,J,LL) !lzhang
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(642))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(642))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          BC WET (HYDROPHILIC BLACK CARBON)
           IF (IGET(643)>0) THEN
             IF (LVLS(L,IGET(643))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(SOOT(I,J,LL,2)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   !GRID1(I,J) = SOOT(I,J,LL,2)
                   GRID1(I,J) = SOOT(I,J,LL,2)*RHOMID(I,J,LL) !lzhang
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(643))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(643))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF


         if (nasa_on) then
!          NITRATE 
           IF (IGET(688)>0) THEN
             IF (LVLS(L,IGET(688))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(NO3(I,J,LL,1)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   GRID1(I,J) = NO3(I,J,LL,1)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(688))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(688))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          NH4 
           IF (IGET(689)>0) THEN
             IF (LVLS(L,IGET(689))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                 IF(NH4(I,J,LL,1)<spval.and.RHOMID(I,J,LL)<spval)THEN
                   GRID1(I,J) = NH4(I,J,LL,1)*RHOMID(I,J,LL) !lzhang ug/kg-->ug/m3
                 ELSE
                   GRID1(I,J) = spval
                 ENDIF
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(689))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(689))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF
          endif !nasa_on
         endif !gocart_on
         
!          AIR DENSITY
           IF (IGET(644)>0) THEN
             IF (LVLS(L,IGET(644))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = RHOMID(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(644))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(644))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

!          LAYER THICKNESS
           IF (IGET(645)>0) THEN
             IF (LVLS(L,IGET(645))>0) THEN
               LL=LM-L+1 
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = DPRES(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(645))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(645))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
             END IF
           ENDIF

! CRA DUST FROM WRF CHEM: Removed ths section because GOCART can output
! the same fields above (Chuang 2012-03-07)

! CRA
!
 190     CONTINUE
!
!     END OF MDL SURFACE OUTPUT BLOCK.
!
      ENDIF
!   VISIBILITY
!     IF (IGET(180)>0) THEN
!comment out until we get QICE, QSNOW brought into post
!MEB   RDTPHS= 1./(NPHS*DT)
!MEB modifying this Eta-specific code, assuming WRF physics will
!MEB explicitly predict vapor/water/ice/rain/snow
!MEB comments starting with MEB are lines associated with this
!MEB Eta-specific code
!            NEED TO CALCULATE RAIN WATER AND SNOW MIXING RATIOS
!      DO J=JSTA,JEND
!      DO I=ista,iend
!MEB     IF (PREC(I,J)==0) THEN
!MEB       QSNO(I,J)=0.
!MEB       QRAIN(I,J)=0.
!MEB     ELSE
!MEB       LLMH=LMH(I,J)
!MEB       SNORATE=SR(I,J)*PREC(I,J)*RDTPHS
!MEB       RAINRATE=(1-SR(I,J))*PREC(I,J)*RDTPHS
!MEB       TERM1=(T(I,J,LM)/PSLP(I,J))**0.4167
!MEB       TERM2=(T(I,J,LLMH)/PMID(I,J,LMH(I,J)))**0.5833
!MEB       TERM3=RAINRATE**0.8333
!MEB       QRAIN(I,J)=RAINCON*TERM1*TERM2*TERM3
!MEB       TERM4=(T(I,J,LM)/PSLP(I,J))**0.47
!MEB       TERM5=(T(I,J,LLMH)/PMID(I,J,LMH(I,J)))**0.53
!MEB       TERM6=SNORATE**0.94
!MEB       QSNO(I,J)=SNOCON*TERM4*TERM5*TERM6
!MEB     ENDIF
!        LLMH=NINT(LMH(I,J))
!        QRAIN1(I,J)=QRAIN(I,J,LLMH)
!        QSNO1(I,J)=QSNOW(I,J,LLMH)
!        TT(I,J)=T(I,J,LLMH)
!        QV(I,J)=Q(I,J,LLMH)
!        QCD(I,J)=CWM(I,J,LLMH)
!        QICE1(I,J)=QICE(I,J,LLMH)
!        PPP(I,J)=PMID(I,J,LLMH)
!      ENDDO
!      ENDDO
!      CALL CALVIS(QV,QCD,QRAIN1,QICE1,QSNO1,TT,PPP,VIS)
!              DO J=JSTA,JEND
!              DO I=ista,iend
!                GRID1(I,J)=VIS(I,J)
!              ENDDO
!              ENDDO
!      ID(1:25) = 0
!      CALL GRIBIT(IGET(180),LVLS(1,IGET(180)),
!    X           GRIDista,iend,JM)
!      ENDIF
!
!     INSTANTANEOUS CONVECTIVE PRECIPITATION RATE.
!
!      IF (IGET(249)>0) THEN
!         RDTPHS=1000./DTQ2
!         DO J=JSTA,JEND
!         DO I=ista,iend
!           GRID1(I,J)=CPRATE(I,J)*RDTPHS
!           GRID1(I,J)=SPVAL
!         ENDDO
!         ENDDO
!         ID(1:25) = 0
!	 CALL GRIBIT(IGET(249),LM,GRIDista,iend,JM)
!      ENDIF
!
!     COMPOSITE RADAR REFLECTIVITY (maximum dBZ in each column)
!
      IF (IGET(252) > 0) THEN
        IF(IMP_PHYSICS /= 8 .and. IMP_PHYSICS /= 28) THEN
!$omp parallel do private(i,j,l)
          DO J=JSTA,JEND
            DO I=ista,iend
               GRID1(I,J) = DBZmin
               DO L=1,NINT(LMH(I,J))
                  GRID1(I,J) = MAX( GRID1(I,J), DBZ(I,J,L) )
               ENDDO
            ENDDO
          ENDDO
        ELSE
!tgs - for Thompson or Milbrandt scheme
!
! CRA Use WRF Thompson reflectivity diagnostic from RAPR model output
!     Use unipost reflectivity diagnostic otherwise
!
          IF(IMP_PHYSICS == 8 .or. IMP_PHYSICS == 28) THEN
!NMMB does not have composite radar ref in model output
           IF(MODELNAME=='NMM' .and. gridtype=='B' .or.  & 
              MODELNAME=='NCAR'.or.  MODELNAME=='FV3R' .or. &
              MODELNAME=='GFS' .or. &
              MODELNAME=='NMM' .and. gridtype=='E')THEN
!$omp parallel do private(i,j,l)
              DO J=JSTA,JEND
                DO I=ista,iend
                  GRID1(I,J) = DBZmin
                  DO L=1,NINT(LMH(I,J))
                    GRID1(I,J) = MAX( GRID1(I,J), REF_10CM(I,J,L) )
                  ENDDO
                ENDDO
              ENDDO 
            ELSE
!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                  GRID1(I,J) = REFC_10CM(I,J)
                ENDDO
              ENDDO
            END IF
            CALL BOUND(GRID1,DBZmin,DBZmax)
          ELSE
!$omp parallel do private(i,j)
            DO J=JSTA,JEND
              DO I=ista,iend
                GRID1(I,J) = refl(i,j)
              ENDDO
            ENDDO
          ENDIF
! CRA
        ENDIF
         if(grib=="grib2") then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(252))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
               ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
!     COMPUTE VIL (radar derived vertically integrated liquid water in each column)
!     Per Mei Xu, VIL is radar derived vertically integrated liquid water based
!     on emprical conversion factors (0.00344) 
      IF (IGET(581)>0) THEN
        DO J=JSTA,JEND
          DO I=ista,iend
            GRID1(I,J)=0.0
            DO L=1,NINT(LMH(I,J))
              if(zint(i,j,l) < spval .and.zint(i,j,l+1)<spval.and.DBZ(I,J,L)<spval) then
                GRID1(I,J)=GRID1(I,J)+0.00344* &
                (10.**(DBZ(I,J,L)/10.))**0.57143*(ZINT(I,J,L)-ZINT(I,J,L+1))/1000.
              else
                GRID1(I,J)=spval
              endif
            ENDDO
          ENDDO
        ENDDO
        if(grib=="grib2") then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(581))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
               ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
        endif
      ENDIF
!
!--   COMPOSITE RADAR REFLECTIVITY FROM RAIN (maximum dBZ in each column due to rain)
!
      IF (IGET(276)>0) THEN
         DO J=JSTA,JEND
            DO I=ista,iend
               GRID1(I,J)=DBZmin
               DO L=1,NINT(LMH(I,J))
                  GRID1(I,J)=MAX( GRID1(I,J), DBZR(I,J,L) )
               ENDDO
            ENDDO
         ENDDO
         if(grib=="grib2") then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(276))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
               ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
!--   COMPOSITE RADAR REFLECTIVITY FROM ICE
!     (maximum dBZ in each column due to all ice habits; snow + graupel + etc.)
!
      IF (IGET(277)>0) THEN
         DO J=JSTA,JEND
            DO I=ista,iend
               GRID1(I,J)=DBZmin
               DO L=1,NINT(LMH(I,J))
                  GRID1(I,J)=MAX( GRID1(I,J), DBZI(I,J,L) )
               ENDDO
            ENDDO
         ENDDO
         if(grib=="grib2") then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(277))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
               ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
!--   COMPOSITE RADAR REFLECTIVITY FROM PARAMETERIZED CONVECTION
!     (maximum dBZ in each column due to parameterized convection, as bogused into
!      post assuming a constant reflectivity from the surface to the 0C level, 
!      and decreasing with height at higher levels)
!
      IF (IGET(278)>0) THEN
         DO J=JSTA,JEND
            DO I=ista,iend
               GRID1(I,J)=DBZmin
               DO L=1,NINT(LMH(I,J))
                  GRID1(I,J)=MAX( GRID1(I,J), DBZC(I,J,L) )
               ENDDO
            ENDDO
         ENDDO
         if(grib=="grib2") then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(278))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
               ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF

! SRD -- converted to kft
! J.Case, ENSCO Inc. (5/26/2008) -- Output Echo Tops (Highest HGT in meters
! of the 18-dBZ reflectivity on a model level)

      IF (IGET(426)>0) THEN
         DO J=JSTA,JEND
            DO I=ista,iend
               GRID1(I,J)=0.0
               DO L=1,NINT(LMH(I,J))
                  IF (DBZ(I,J,L)>=18.0) THEN
                     GRID1(I,J)=ZMID(I,J,L)*3.2808/1000.
                     EXIT
                  ENDIF
               ENDDO
            ENDDO
         ENDDO
         if(grib=="grib2") then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(426))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
               ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
! J.Case (end mods)
! SRD

! CRA
! NCAR fields
! Echo top height (Highest height in meters of 11-dBZ reflectivity
! interpolated from adjacent model levels in column containing 18-dBZ)
! Use WRF Thompson reflectivity diagnostic from RAPR model output
! Use unipost reflectivity diagnostic otherwise
!
      IF (IGET(768) > 0) THEN
        IF(MODELNAME == 'RAPR' .AND. (IMP_PHYSICS == 8 .or. IMP_PHYSICS == 28)) THEN
          DO J=JSTA,JEND
            DO I=ista,iend
              GRID1(I,J) = -999.
              DO L=1,NINT(LMH(I,J))
                IF (REF_10CM(I,J,L)>=18.0) THEN
                   GRID1(I,J)=ZMID(I,J,L)
                   EXIT
                 ENDIF
              ENDDO
              IF(GRID1(I,J) >= -900) THEN
                DO L=1,NINT(LMH(I,J))
                  IF (REF_10CM(I,J,L) >= 11.0) THEN
                    IF(L == 1) THEN
                      GRID1(I,J) = ZMID(I,J,L)
                    ELSE IF(REF_10CM(I,J,L-1) ==  REF_10CM(I,J,L)) THEN
                      GRID1(I,J) = ZMID(I,J,L)
                    ELSE
                      GRID1(I,J) = ZMID(I,J,L) +                        &
                                  (11.0 - REF_10CM(I,J,L)) *            &
                                  (ZMID(I,J,L-1) - ZMID(I,J,L)) /       &
                                  (REF_10CM(I,J,L-1) - REF_10CM(I,J,L))
                    ENDIF
                    EXIT
                  ENDIF
                ENDDO
              ENDIF
            ENDDO
          ENDDO
        ELSE
          DO J=JSTA,JEND
            DO I=ista,iend
              GRID1(I,J) = -999.
              DO L=1,NINT(LMH(I,J))
                IF (DBZ(I,J,L) >= 18.0) THEN
                   GRID1(I,J) = ZMID(I,J,L)
                   EXIT
                ENDIF
              ENDDO
            ENDDO
          ENDDO
        ENDIF
       if(grib=="grib2") then
         cfld=cfld+1
         fld_info(cfld)%ifld=IAVBLFLD(IGET(768))
!$omp parallel do private(i,j,ii,jj)
         do j=1,jend-jsta+1
           jj = jsta+j-1
           do i=1,iend-ista+1
             ii = ista+i-1
             datapd(i,j,cfld) = GRID1(ii,jj)
           enddo
         enddo
       endif
      ENDIF
!
! Vertically integrated liquid in kg/m^2
!
      IF (IGET(769)>0) THEN
         DO J=JSTA,JEND
            DO I=ista,iend
               GRID1(I,J)=0.0
               DO L=1,NINT(LMH(I,J))
               IF(QQR(I,J,L)<spval.and.QQS(I,J,L)<spval.and.QQG(I,J,L)<spval.and.&
                  ZINT(I,J,L)<spval.and.ZINT(I,J,L+1)<spval.and.&
                  PMID(I,J,L)<spval.and.T(I,J,L)<spval.and.Q(I,J,L)<spval)THEN
                  IF(QQH(I,J,L)<spval)THEN
                     GRID1(I,J)=GRID1(I,J) + (QQR(I,J,L) + QQH(I,J,L) + &
                                  QQS(I,J,L) + QQG(I,J,L))*     &
                                (ZINT(I,J,L)-ZINT(I,J,L+1))*PMID(I,J,L)/  &
                                (RD*T(I,J,L)*(Q(I,J,L)*D608+1.0))
                  ELSE
                     GRID1(I,J)=GRID1(I,J) + (QQR(I,J,L) +      &
                                  QQS(I,J,L) + QQG(I,J,L))*     &
                                (ZINT(I,J,L)-ZINT(I,J,L+1))*PMID(I,J,L)/  &
                                (RD*T(I,J,L)*(Q(I,J,L)*D608+1.0))
                  ENDIF
               ELSE
                  GRID1(I,J)=spval
               ENDIF
               ENDDO
            ENDDO
         ENDDO
         if(grib=="grib2") then
           cfld=cfld+1
           fld_info(cfld)%ifld=IAVBLFLD(IGET(769))
!$omp parallel do private(i,j,ii,jj)
           do j=1,jend-jsta+1
             jj = jsta+j-1
             do i=1,iend-ista+1
               ii = ista+i-1
               datapd(i,j,cfld) = GRID1(ii,jj)
             enddo
           enddo
         endif
      ENDIF
!
! Vertically integrated liquid based on reflectivity factor in kg/m^2
! Use WRF Thompson reflectivity diagnostic from RAPR model output
! Use unipost reflectivity diagnostic otherwise
!
      IF (IGET(770) > 0) THEN
        IF(MODELNAME == 'RAPR' .AND. (IMP_PHYSICS == 8 .or. IMP_PHYSICS == 28)) THEN
          DO J=JSTA,JEND
            DO I=ista,iend
              GRID1(I,J) = 0.0
              DO L=1,NINT(LMH(I,J))
                IF (REF_10CM(I,J,L) > -10.0 ) THEN
                  GRID1(I,J) = GRID1(I,J) + 0.00344 *                &
                             (10.**(REF_10CM(I,J,L)/10.))**0.57143 * &
                             (ZINT(I,J,L)-ZINT(I,J,L+1))/1000.
                ENDIF
              ENDDO
            ENDDO
          ENDDO
        ELSE
          DO J=JSTA,JEND
            DO I=ista,iend
              GRID1(I,J) = 0.0
              DO L=1,NINT(LMH(I,J))
                GRID1(I,J) = GRID1(I,J) + 0.00344 *                 &
                            (10.**(DBZ(I,J,L)/10.))**0.57143 *      &
                            (ZINT(I,J,L)-ZINT(I,J,L+1))/1000.
              ENDDO
            ENDDO
          ENDDO
        ENDIF
        if(grib=="grib2") then
          cfld=cfld+1
          fld_info(cfld)%ifld=IAVBLFLD(IGET(770))
!$omp parallel do private(i,j,ii,jj)
          do j=1,jend-jsta+1
            jj = jsta+j-1
            do i=1,iend-ista+1
              ii = ista+i-1
              datapd(i,j,cfld) = GRID1(ii,jj)
            enddo
          enddo
        endif
      ENDIF
! CRA

!
!---   VISIBILITY
!
      IF (IGET(180)>0) THEN
        RDTPHS=1./DTQ2
  !
  !--- Needed values at 1st level above ground  (Jin, '01; Ferrier, Feb '02)
  !
        DO J=JSTA,JEND
          DO I=ista,iend
            LLMH=NINT(LMH(I,J))
            Q1D(I,J)=Q(I,J,LLMH)
           if(Q1D(I,J)<=0.) Q1D(I,J)=0.         !tgs
            QW1(I,J)=QQW(I,J,LLMH)
            QR1(I,J)=QQR(I,J,LLMH)
            QI1(I,J)=QQI(I,J,LLMH)
            QS1(I,J)=QQS(I,J,LLMH)
            QG1(I,J)=QQG(I,J,LLMH)      !tgs
            T1D(I,J)=T(I,J,LLMH)
            P1D(I,J)=PMID(I,J,LLMH)

!HC July 2012, per communication with Ferrier, modify post to add convective 
!   contribution to visibility for all non GFS models

!           IF(MODELNAME/='GFS')THEN
           IF(imp_physics/=99)THEN
            IF (CPRATE(I,J) > 0. .and. CPRATE(I,J) < SPVAL &
                .and. PMID(I,J,LM) < spval .and. QR1(I,J) < spval) THEN
!            IF (CUPPT(I,J) > 0.) THEN
               RAINRATE=(1-SR(I,J))*CPRATE(I,J)*RDTPHS
!               RAINRATE=(1-SR(I,J))*CUPPT(I,J)/(TRDLW*3600.)
               TERM1=(T(I,J,LM)/PMID(I,J,LM))**0.4167
               TERM2=(T1D(I,J)/P1D(I,J))**0.5833
               TERM3=RAINRATE**0.8333
	       QROLD=1.2*QR1(I,J)
               QR1(I,J)=QR1(I,J)+RAINCON*TERM1*TERM2*TERM3
               IF (SR(I,J) > 0. .and. QS1(I,J) < SPVAL) THEN
                  SNORATE=SR(I,J)*CPRATE(I,J)*RDTPHS
!                  SNORATE=SR(I,J)*CUPPT(I,J)/(TRDLW*3600.)
                  TERM1=(T(I,J,LM)/PMID(I,J,LM))**0.47
                  TERM2=(T1D(I,J)/P1D(I,J))**0.53
                  TERM3=SNORATE**0.94
                  QS1(I,J)=QS1(I,J)+SNOCON*TERM1*TERM2*TERM3
               ENDIF
            ENDIF
	   ELSE !imp_physics is 99 
! Zhao microphysics option in NMMB is identified as 9
! However, microphysics option 9 in WRF is Milbrandt-Yau 2-moment scheme.   
! 3/14/2013: Ratko comitted NEMS change (r26409) to change mp_physics from 9 to 99 for Zhao
! scheme used with NMMB.  Post is changing accordingly
!	   IF(imp_physics==99)THEN ! use rain rate for visibility
            IF (prec(i,j) < spval .and. prec(I,J) > 0. .and.  &
             sr(i,j)<spval) THEN
!            IF (CUPPT(I,J) > 0.) THEN
               RAINRATE=(1-SR(I,J))*PREC(I,J)*RDTPHS
!               RAINRATE=(1-SR(I,J))*CUPPT(I,J)/(TRDLW*3600.)
               TERM1=(T(I,J,LM)/PMID(I,J,LM))**0.4167
               TERM2=(T1D(I,J)/P1D(I,J))**0.5833
               TERM3=RAINRATE**0.8333
	       QROLD=1.2*QR1(I,J)
               QR1(I,J)=QR1(I,J)+RAINCON*TERM1*TERM2*TERM3
               IF (SR(I,J) > 0.) THEN
                  SNORATE=SR(I,J)*PREC(I,J)*RDTPHS
!                  SNORATE=SR(I,J)*CUPPT(I,J)/(TRDLW*3600.)
                  TERM1=(T(I,J,LM)/PMID(I,J,LM))**0.47
                  TERM2=(T1D(I,J)/P1D(I,J))**0.53
                  TERM3=SNORATE**0.94
                  QS1(I,J)=QS1(I,J)+SNOCON*TERM1*TERM2*TERM3
               ENDIF
            ENDIF
           END IF

          ENDDO
        ENDDO
!
!-- Visibility using Warner-Stoelinga algorithm  (Jin, '01)
!
        ii=(ista+iend)/2
        jj=(jsta+jend)/2
!        print*,'Debug: Visbility ',Q1D(ii,jj),QW1(ii,jj),QR1(ii,jj)
!     +,QI1(ii,jj) ,QS1(ii,jj),T1D(ii,jj),P1D(ii,jj)

        CALL CALVIS(Q1D,QW1,QR1,QI1,QS1,T1D,P1D,VIS)

!        print*,'Debug: Visbility ',Q1D(ii,jj),QW1(ii,jj),QR1(ii,jj),QI1(ii,jj)
!     +,QS1(ii,jj),T1D(ii,jj),P1D(ii,jj)
!

	 DO J=JSTA,JEND
	 DO I=ista,iend
	  IF(vis(i,j)/=spval.and.abs(vis(i,j))>24135.1)print*,'bad visbility'     &
       , i,j,Q1D(i,j),QW1(i,j),QR1(i,j),QI1(i,j)                 &
       , QS1(i,j),T1D(i,j),P1D(i,j),vis(i,j)

         GRID1(I,J)=VIS(I,J)
	END DO
	END DO  
        if(grib=="grib2") then
         cfld=cfld+1
         fld_info(cfld)%ifld=IAVBLFLD(IGET(180))
         fld_info(cfld)%lvl=LVLSXML(1,IGET(180))
         datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
       endif
       ENDIF

!
! --- GSD VISIBILITY
!
      IF (IGET(410)>0) THEN
        CALL CALVIS_GSD(CZEN,VIS)
        DO J=JSTA,JEND
        DO I=ista,iend
          GRID1(I,J)=VIS(I,J)
        END DO
        END DO
        if(grib=="grib2") then
         cfld=cfld+1
         fld_info(cfld)%ifld=IAVBLFLD(IGET(410))
         fld_info(cfld)%lvl=LVLSXML(1,IGET(410))
         datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
        endif
      ENDIF
!
! --- RADAR REFLECT - 1km
!
      IF (IGET(748) > 0) THEN
!
! CRA Use WRF Thompson reflectivity diagnostic from RAPR model output
!     Use unipost reflectivity diagnostic otherwise
!
        IF(MODELNAME == 'RAPR' .AND. (IMP_PHYSICS == 8 .or. IMP_PHYSICS == 28)) THEN
          GRID1 = -20.0
!$omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ista,iend
              GRID1(I,J) = REF1KM_10CM(I,J)
            END DO
          END DO
          CALL BOUND(GRID1,DBZmin,DBZmax)
        ELSE
!$omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ista,iend
              GRID1(I,J) = refl1km(I,J)
            END DO
          END DO
        ENDIF
! CRA
!      print *,'MAX/MIN radar reflct - 1km ',maxval(grid1),minval(grid1)
        if(grib=="grib2") then
         cfld=cfld+1
         fld_info(cfld)%ifld=IAVBLFLD(IGET(748))
         fld_info(cfld)%lvl=LVLSXML(1,IGET(748))
         datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
        endif
       ENDIF

!
! --- RADAR REFLECT - 4km
!
      IF (IGET(757) > 0) THEN
!
! CRA Use WRF Thompson reflectivity diagnostic from RAPR model output
!     Use unipost reflectivity diagnostic otherwise
!
        IF(MODELNAME == 'RAPR' .AND. (IMP_PHYSICS == 8 .or. IMP_PHYSICS == 28)) THEN
!$omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ista,iend
              GRID1(I,J) = REF4KM_10CM(I,J)
            END DO
          END DO
          CALL BOUND(GRID1,DBZmin,DBZmax)
        ELSE
!$omp parallel do private(i,j)
          DO J=JSTA,JEND
            DO I=ista,iend
              GRID1(I,J) = refl4km(I,J)
            END DO
          END DO
        ENDIF
! CRA
!      print *,'MAX/MIN radar reflct - 4km ',maxval(grid1),minval(grid1)
        if(grib=="grib2") then
         cfld=cfld+1
         fld_info(cfld)%ifld=IAVBLFLD(IGET(757))
         fld_info(cfld)%lvl=LVLSXML(1,IGET(757))
         datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
        endif
       ENDIF

! RADAR REFLECTIVITY AT -10C LEVEL
       IF (IGET(912)>0) THEN
         Zm10c=spval
         DO J=JSTA,JEND
         DO I=ista,iend
! dong handle missing value
          if (slp(i,j) < spval) then
          Zm10c(I,J)=ZMID(I,J,NINT(LMH(I,J)))
          DO L=NINT(LMH(I,J)),1,-1
             IF (T(I,J,L) <= 263.15) THEN
               Zm10c(I,J)= L        !-- Find lowest level where T<-10C
               EXIT
             ENDIF
          ENDDO
          end if ! spval
         ENDDO
         ENDDO

! REFD at -10 C level
!
! CRA Use WRF Thompson reflectivity diagnostic from RAPR model output
!     Use unipost reflectivity diagnostic otherwise
! Chuang: use Thompson reflectivity direct output for all
! models 
! 
         IF(IMP_PHYSICS==8 .or. IMP_PHYSICS==28) THEN 
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
           DO I=ista,iend
            GRID1(I,J)=spval
! dong handle missing value
            if (slp(i,j) < spval) then
             GRID1(I,J)=REF_10CM(I,J,Zm10c(I,J))
            end if ! spval
           ENDDO
           ENDDO
         ELSE 
!$omp parallel do private(i,j)
           DO J=JSTA,JEND
           DO I=ista,iend
            GRID1(I,J)=spval
! dong handle missing value
            if (slp(i,j) < spval) then
             GRID1(I,J)=DBZ(I,J,Zm10c(I,J))
            end if ! spval
           ENDDO
           ENDDO
         ENDIF

         CALL BOUND(GRID1,DBZmin,DBZmax)

         if(grib=="grib2" )then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(912))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(912))
                 datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
         endif
       ENDIF
!     
!     ASYMPTOTIC AND FREE ATMOSPHERE MASTER LENGTH SCALE (EL), PLUS
!     GRADIENT RICHARDSON NUMBER.
!
      IF ( (IGET(111)>0) .OR. (IGET(146)>0) .OR.         &
           (IGET(147)>0) ) THEN
!     
!        COMPUTE ASYMPTOTIC MASTER LENGTH SCALE.
         CALL CLMAX(EL0(1,jsta),EGRID2(1,jsta),EGRID3(1,jsta),EGRID4(1,jsta),EGRID5(1,jsta))
!     
!        IF REQUESTED, POST ASYMPTOTIC MASTER LENGTH SCALE.
         IF (IGET(147)>0) THEN
!
               DO J=JSTA,JEND
               DO I=ista,iend
                 GRID1(I,J) = EL0(I,J)
               ENDDO
               ENDDO
            if(grib=="grib2") then
              cfld=cfld+1
              fld_info(cfld)%ifld=IAVBLFLD(IGET(147))
              datapd(1:iend-ista+1,1:jend-jsta+1,cfld)=GRID1(ista:iend,jsta:jend)
            endif
         ENDIF
!     
!        IF REQUESTED, POST FREE ATMOSPHERE MASTER LENGTH SCALE
!        AND/OR THE GRADIENT RICHARDSON NUMBER.    
!
         IF ( (IGET(111)>0) .OR. (IGET(146)>0) ) THEN
!     
!           COMPUTE FREE ATMOSPHERE MASTER LENGTH SCALE.
!$omp  parallel do private(i,j,l)
            DO L=1,LM
              DO J=JSTA,JEND
                DO I=ista,iend
                   EL(I,J,L) = D00
                ENDDO
              ENDDO
            ENDDO

            IF(MODELNAME == 'NCAR'.OR.MODELNAME=='RSM'.OR. MODELNAME == 'RAPR')THEN
!             CALL MIXLEN(EL0,EL)  
            ELSE IF(MODELNAME == 'NMM')THEN
              DO L=1,LM
               DO J=JSTA,JEND
               DO I=ista,iend
                 EL(I,J,L)=EL_PBL(I,J,L)  !NOW EL COMES OUT OF WRF NMM
               ENDDO
               ENDDO
              ENDDO
            END IF
!     
!           COMPUTE GRADIENT RICHARDSON NUMBER IF REQUESTED.
!     
            IF ( (IGET(111)>0) ) CALL CALRCH(EL,RICHNO)
!
!           LOOP OVER MDL LAYERS.
            DO 200 L = 1,LM
!     
!              POST MIXING LENGTH.
!
            IF (IGET(146)>0) THEN
!
!
             IF (LVLS(L,IGET(146))>0) THEN
               LL=LM-L+1
!$omp  parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = EL(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                fld_info(cfld)%ifld=IAVBLFLD(IGET(146))
                fld_info(cfld)%lvl=LVLSXML(L,IGET(146))
!$omp parallel do private(i,j,ii,jj)
                do j=1,jend-jsta+1
                  jj = jsta+j-1
                  do i=1,iend-ista+1
                    ii = ista+i-1
                    datapd(i,j,cfld) = GRID1(ii,jj)
                  enddo
                enddo
               endif
             ENDIF
            ENDIF
!     
!              POST GRADIENT RICHARDSON NUMBER.
!
            IF(L < LM)THEN
             IF (IGET(111)>0) THEN
              IF (LVLS(L,IGET(111))>0) THEN
               LL=LM-L+1
!$omp parallel do private(i,j)
               DO J=JSTA,JEND
                 DO I=ista,iend
                   GRID1(I,J) = RICHNO(I,J,LL)
                 ENDDO
               ENDDO
               if(grib=="grib2") then
                 cfld=cfld+1
                 fld_info(cfld)%ifld=IAVBLFLD(IGET(111))
                 fld_info(cfld)%lvl=LVLSXML(L,IGET(111))
!$omp parallel do private(i,j,ii,jj)
                 do j=1,jend-jsta+1
                   jj = jsta+j-1
                   do i=1,iend-ista+1
                     ii = ista+i-1
                     datapd(i,j,cfld) = GRID1(ii,jj)
                   enddo
                 enddo
               endif
              ENDIF
            ENDIF
           END IF

 200        CONTINUE
!
!
         ENDIF
      ENDIF
!     
!           COMPUTE PBL HEIGHT BASED ON RICHARDSON NUMBER
!     
            IF ( (IGET(289)>0) .OR. (IGET(389)>0) .OR. (IGET(454)>0)   &
            .OR. (IGET(245)>0)  .or. IGET(464)>0 .or. IGET(467)>0  &
            .or. IGET(470)>0 .or. IGET(476)>0) THEN
! should only compute pblri if pblh from model is not computed based on Ri 
! post does not yet read pbl scheme used by model.  Will do this soon
! For now, compute PBLRI for non GFS models.
              IF(MODELNAME  ==  'GFS')THEN
                PBLRI=PBLH
              ELSE
               CALL CALPBL(PBLRI)
              END IF
            END IF  

            IF (IGET(289) > 0) THEN
!$omp parallel do private(i,j)
                DO J=JSTA,JEND
                  DO I=ista,iend
                     GRID1(I,J) = PBLRI(I,J)
!                    PBLH(I,J) = PBLRI(I,J)
                  ENDDO
                ENDDO
                if(grib=="grib2") then
                  Cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(289))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                    jj = jsta+j-1
                    do i=1,iend-ista+1
                      ii = ista+i-1
                      datapd(i,j,cfld) = GRID1(ii,jj)
                    enddo
                  enddo
                endif
            ENDIF
! Pyle
!       COMPUTE TRANSPORT WIND COMPONENTS (AVG WIND OVER MIXED LAYER)
!
!mp     have model layer heights (ZMID, known) so we can average the winds (known) up to the PBLH (known)

            IF ( (IGET(389) > 0) .OR. (IGET(454) > 0) ) THEN
!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                IF(PBLRI(I,J)<spval.and.ZINT(I,J,LM+1)<spval)THEN
                  EGRID3(I,J) = PBLRI(I,J) + ZINT(I,J,LM+1)
                ELSE
                  EGRID3(I,J) = spval
                ENDIF
                END DO
              END DO  
! compute U and V separately because they are on different locations for B grid
              CALL H2U(EGRID3(ista_2l:iend_2u,JSTA_2L:JEND_2U),EGRID4)
!$omp parallel do private(i,j)
              DO J=JSTA,JEND
                DO I=ista,iend
                  EGRID1(I,J) = 0.0
                  EGRID2(I,J) = 0.0
                END DO
              END DO
  vert_loopu: DO L=LM,1,-1
                 CALL H2U(ZMID(ista_2l:iend_2u,JSTA_2L:JEND_2U,L),  EGRID5)
                 CALL H2U(PINT(ista_2l:iend_2u,JSTA_2L:JEND_2U,L+1),EGRID6)
                 CALL H2U(PINT(ista_2l:iend_2u,JSTA_2L:JEND_2U,L),  EGRID7)
                 HCOUNT=0
                 DO J=JSTA,JEND
                  DO I=ista,iend
                   if (EGRID4(I,J)<spval.and.EGRID5(I,J)<spval.and.&
                       EGRID6(I,J)<spval.and.EGRID7(I,J)<spval.and.&
                       UH(I,J,1)<spval)THEN
                   if (EGRID5(I,J)  <=  EGRID4(I,J)) then
                    HCOUNT      = HCOUNT+1
                    DP          = EGRID6(I,J) - EGRID7(I,J)
                    EGRID1(I,J) = EGRID1(I,J) + UH(I,J,L)*DP
                    EGRID2(I,J) = EGRID2(I,J) + DP
!                  else
!                    exit vert_loopu
                   endif
                   endif
                  end do
                end do 
                 if(HCOUNT < 1 )exit vert_loopu
              ENDDO vert_loopu
!$omp parallel do private(i,j)
                DO J=JSTA,JEND
                  DO I=ista,iend
                    IF(EGRID2(I,J) > 0.)THEN
                      GRID1(I,J) = EGRID1(I,J)/EGRID2(I,J)
                    ELSE
                      GRID1(I,J) = U10(I,J) ! IF NO MIX LAYER, SPECIFY 10 M WIND, PER DIMEGO,
                    END IF
                    USTORE(I,J) = GRID1(I,J)
                  END DO
                END DO 
! compute v component now
                CALL H2V(EGRID3(ista_2l:iend_2u,JSTA_2L:JEND_2U),EGRID4)
!$omp parallel do private(i,j)
                DO J=JSTA,JEND
                  DO I=ista,iend
                    EGRID1(i,j) = 0.
                    EGRID2(i,j) = 0.
                    EGRID5(i,j) = 0.
                    EGRID6(i,j) = 0.
                    EGRID7(i,j) = 0.
                  END DO
                END DO
  vert_loopv:   DO L=LM,1,-1
	         CALL H2V(ZMID(ista_2l:iend_2u,JSTA_2L:JEND_2U,L),  EGRID5)
		 CALL H2V(PINT(ista_2l:iend_2u,JSTA_2L:JEND_2U,L+1),EGRID6)
		 CALL H2V(PINT(ista_2l:iend_2u,JSTA_2L:JEND_2U,L),  EGRID7)
		 HCOUNT=0
                 DO J=JSTA,JEND
                  DO I=ista,iend
                   if (EGRID4(I,J)<spval.and.EGRID5(I,J)<spval.and.&
                       EGRID6(I,J)<spval.and.EGRID7(I,J)<spval.and.&
                       VH(I,J,1)<spval)THEN
                   if (EGRID5(I,J) <= EGRID4(I,J)) then
                     HCOUNT=HCOUNT+1
                     DP = EGRID6(I,J) - EGRID7(I,J)
                     EGRID1(I,J) = EGRID1(I,J) + VH(I,J,L)*DP
                     EGRID2(I,J) = EGRID2(I,J) + DP
!                  else
!                    exit vert_loopu
                   endif
                   endif 
                  end do
                 end do 
                 if(HCOUNT<1)exit vert_loopv
                ENDDO vert_loopv
!$omp parallel do private(i,j)
                DO J=JSTA,JEND
                  DO I=ista,iend
                    IF(EGRID2(I,J) > 0.)THEN
                      GRID2(I,J) = EGRID1(I,J)/EGRID2(I,J)
                    ELSE
                      GRID2(I,J) = V10(I,J) ! IF NO MIX LAYER, SPECIFY 10 M WIND, PER DIMEGO,
                    END IF
                    VSTORE(I,J) = GRID2(I,J)
                  END DO
                END DO 


                CALL U2H(USTORE,EGRID1)
                CALL V2H(VSTORE,EGRID2)
!$omp parallel do private(i,j)
                DO J=JSTA,JEND
                  DO I=ista,iend

! EGRID1 is transport wind speed
                     ! prevent floating overflow if either component is undefined
                     IF (EGRID1(I,J)<SPVAL .and. EGRID2(I,J)<SPVAL) THEN
                       EGRID3(I,J) = sqrt((EGRID1(I,J)*EGRID1(I,J)+EGRID2(I,J)*EGRID2(I,J)))
                     ELSe
                       EGRID3(I,J) = SPVAL
                     END IF
                   ENDDO
                 ENDDO

               IF(IGET(389) > 0)THEN
                if(grib=='grib2') then
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(389))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                    jj = jsta+j-1
                    do i=1,iend-ista+1
                      ii=ista+i-1
                      datapd(i,j,cfld) = GRID1(ii,jj)
                    enddo
                  enddo
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(390))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                    jj = jsta+j-1
                    do i=1,iend-ista+1
                    ii=ista+i-1
                      datapd(i,j,cfld) = GRID2(ii,jj)
                    enddo
                  enddo
                endif 
               END IF
            ENDIF
!
!       COMPUTE VENTILATION RATE (TRANSPORT WIND SPEED * MIXED LAYER HEIGHT)
!
!       OK Mesonet has it in MKS units, so go with it.  Ignore South Carolina fire
!       comments about the winds being in MPH and the mixing height in feet.

            IF ( (IGET(454) > 0) ) THEN

!$omp parallel do private(i,j)
                DO J=JSTA,JEND
                  DO I=ista,iend

                    IF (PBLRI(I,J) /= SPVAL .and. EGRID3(I,J)/=SPVAL) then
                      GRID1(I,J) = EGRID3(I,J)*PBLRI(I,J)
                    else
                      GRID1(I,J) = 0.
                    ENDIF

                  ENDDO
                ENDDO

                if(grib=='grib2') then
                  Cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(454))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                    jj = jsta+j-1
                    do i=1,iend-ista+1
                      ii = ista+i-1
                      datapd(i,j,cfld) = GRID1(ii,jj)
                    enddo
                  enddo
                endif


            ENDIF
!	    
! CALCULATE Gust based on Ri PBL
      IF (IGET(245)>0 .or. IGET(464)>0 .or. IGET(467)>0.or. IGET(470)>0 .or. IGET(476)>0) THEN
        IF(MODELNAME=='RAPR') THEN
!tgs - 24may17 - smooth PBLHGUST 
           if(MAPTYPE == 6) then
             if(grib=='grib2') then
                dxm = (DXVAL / 360.)*(ERAD*2.*pi)/1.d6  ! [mm]
             endif
           else
              dxm = dxval
           endif
           if(grib == 'grib2')then
              dxm=dxm/1000.0
           endif
!           if(me==0)print *,'dxm=',dxm
           NSMOOTH = nint(5.*(13500./dxm))
           do j = jsta_2l, jend_2u
             do i = ista_2l, iend_2u
               GRID1(i,j)=PBLHGUST(i,j)
             enddo
           enddo
           call AllGETHERV(GRID1)
           do ks=1,nsmooth
             CALL SMOOTH(GRID1,SDUMMY,IM,JM,0.5)
           end do
           do j = jsta_2l, jend_2u
             do i = ista_2l, iend_2u
               PBLHGUST(i,j)=GRID1(i,j)
             enddo
           enddo
        ENDIF

       DO J=JSTA,JEND
        DO I=ista,iend
         LPBL(I,J)=LM

         if(ZINT(I,J,NINT(LMH(I,J))+1) <spval) then

         ZSFC=ZINT(I,J,NINT(LMH(I,J))+1)
         loopL:DO L=NINT(LMH(I,J)),1,-1
          IF(MODELNAME=='RAPR') THEN
           HGT=ZMID(I,J,L)
           PBLHOLD=PBLHGUST(I,J)
          ELSE
           HGT=ZINT(I,J,L)
           PBLHOLD=PBLRI(I,J)
          ENDIF
          IF(HGT >  PBLHOLD+ZSFC)THEN
           LPBL(I,J)=L+1
           IF(LPBL(I,J)>=LP1) LPBL(I,J) = LM
           EXIT loopL 
          END IF
         ENDDO loopL

         else
           LPBL(I,J) = LM
         endif
         if(lpbl(i,j)<1)print*,'zero lpbl',i,j,pblri(i,j),lpbl(i,j)
        ENDDO
       ENDDO
       IF(MODELNAME=='RAPR') THEN
        CALL CALGUST(LPBL,PBLHGUST,GUST)
       ELSE
        CALL CALGUST(LPBL,PBLRI,GUST)
       END IF
       IF (IGET(245)>0) THEN
!$omp parallel do private(i,j)
       DO J=JSTA,JEND
         DO I=ista,iend
!         if(GUST(I,J) > 200. .and. gust(i,j)<spval)    &
!      	 print*,'big gust at ',i,j
           GRID1(I,J) = GUST(I,J)
         ENDDO
       ENDDO      
       if(grib=='grib2') then
        cfld=cfld+1
        fld_info(cfld)%ifld=IAVBLFLD(IGET(245))
!$omp parallel do private(i,j,ii,jj)
        do j=1,jend-jsta+1
          jj = jsta+j-1
          do i=1,iend-ista+1
            ii = ista+i-1
            datapd(i,j,cfld) = GRID1(ii,jj)
          enddo
        enddo
       endif
      ENDIF
      END IF
!     
!           COMPUTE PBL REGIME BASED ON WRF version of BULK RICHARDSON NUMBER
!     

            IF (IGET(344)>0) THEN
                allocate(PBLREGIME(ista_2l:iend_2u,jsta_2l:jend_2u))
                CALL CALPBLREGIME(PBLREGIME)
!$omp parallel do private(i,j)
                DO J=JSTA,JEND
                  DO I=ista,iend
                    GRID1(I,J) = PBLREGIME(I,J)
                  ENDDO
                ENDDO
                if(grib=="grib2") then
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(344))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                    jj = jsta+j-1
                    do i=1,iend-ista+1
                      ii = ista+i-1
                      datapd(i,j,cfld) = GRID1(ii,jj)
                    enddo
                  enddo
                endif
              deallocate(PBLREGIME)
            ENDIF
!
!     RADAR ECHO TOP (highest 18.3 dBZ level in each column)
!
      IF(IGET(400)>0)THEN
        DO J=JSTA,JEND
          DO I=ista,iend
!Initialed as 'undetected'.  Nov. 17, 2014, B. ZHOU:
!changed from SPVAL to -5000. to distinguish missing grids and undetected 
!           GRID1(I,J) = SPVAL      	      
            GRID1(I,J) = -5000.  !undetected initially         
            IF(IMP_PHYSICS == 8.)then ! If Thompson MP
              DO L=1,NINT(LMH(I,J))
                IF(REF_10CM(I,J,L) > 18.3) then
                  GRID1(I,J) = ZMID(I,J,L)
                  EXIT
                ENDIF
              ENDDO
            ELSE ! if other MP than Thompson
              DO L=1,NINT(LMH(I,J))
                IF(DBZ(I,J,L) > 18.3) then
                  GRID1(I,J) = ZMID(I,J,L)
                  EXIT
                END IF
              ENDDO
            END IF
 201        CONTINUE
!           if(grid1(i,j)<0.)print*,'bad echo top',  &
!    +         i,j,grid1(i,j),dbz(i,j,1:lm)	       
          ENDDO
        ENDDO
        if(grib=="grib2") then
         cfld=cfld+1
         fld_info(cfld)%ifld=IAVBLFLD(IGET(400))
!$omp parallel do private(i,j,ii,jj)
         do j=1,jend-jsta+1
           jj = jsta+j-1
           do i=1,iend-ista+1
             ii = ista+i-1
             datapd(i,j,cfld) = GRID1(ii,jj)
           enddo
         enddo
        endif
      ENDIF
!     
!
! COMPUTE NCAR GTG turbulence
      IF(gtg_on .and. (IGET(464) > 0 .or. IGET(467) > 0 .or. IGET(470) > 0)) then
        i=(ista+iend)/2
        j=(jsta+jend)/2
!        if(me == 0) print*,'sending input to GTG i,j,hgt,gust',i,j,ZINT(i,j,LP1),gust(i,j)

        ! Use the existing 3D local arrays as cycled variables
        RICHNO=SPVAL

        call gtg_algo(im,jm,lm,jsta,jend,jsta_2L,jend_2U,&
        uh(ista:iend,:,:),vh(ista:iend,:,:),wh(ista:iend,:,:),&
        zmid(ista:iend,:,:),pmid(ista:iend,:,:),t(ista:iend,:,:),&
        q(ista:iend,:,:),qqw(ista:iend,:,:),qqr(ista:iend,:,:),&
        qqs(ista:iend,:,:),qqg(ista:iend,:,:),qqi(ista:iend,:,:),&
        q2(ista:iend,:,:),&
        ZINT(ista:iend,:,LP1),pblh(ista:iend,:),sfcshx(ista:iend,:),&
        sfclhx(ista:iend,:),ustar(ista:iend,:),&
        z0(ista:iend,:),gdlat(ista:iend,:),gdlon(ista:iend,:),&
        dx(ista:iend,:),dy(ista:iend,:),u10(ista:iend,:),v10(ista:iend,:),&
        GUST(ista:iend,:),avgprec(ista:iend,:),sm(ista:iend,:),sice(ista:iend,:),&
        catedr(ista:iend,:,:),mwt(ista:iend,:,:),cit(ista:iend,:,:),&
        RICHNO(ista:iend,:,:),gtg(ista:iend,:,:),item)

        i=iend
        j=jend ! 321,541
!        print*,'GTG output: l,cat,mwt,gtg at',i,j
!        do l=1,lm
!           print*,l,catedr(i,j,l),mwt(i,j,l),gtg(i,j,l)
!        end do
      ENDIF

      IF (IGET(470)>0) THEN
         Do L=1,LM
            IF (LVLS(L,IGET(470))>0) THEN
               LL=LM-L+1
               DO J=JSTA,JEND
               DO I=ista,iend
                  GRID1(I,J)=gtg(i,j,LL)
               ENDDO
               ENDDO
               if(grib=="grib2")then
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(470))
                  fld_info(cfld)%lvl=LVLSXML(L,IGET(470))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                     jj = jsta+j-1
                     do i=1,iend-ista+1
                       ii = ista+i-1
                       datapd(i,j,cfld) = GRID1(ii,jj)
                     enddo
                  enddo
               endif


               DO J=JSTA,JEND
               DO I=ista,iend
                  GRID1(I,J)=catedr(i,j,LL)
               ENDDO
               ENDDO
               if(grib=="grib2")then
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(471))
                  fld_info(cfld)%lvl=LVLSXML(L,IGET(471))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                     jj = jsta+j-1
                     do i=1,iend-ista+1
                       ii = ista+i-1
                       datapd(i,j,cfld) = GRID1(ii,jj)
                     enddo
                  enddo
               endif

               DO J=JSTA,JEND
               DO I=ista,iend
                  GRID1(I,J)=mwt(i,j,LL)
               ENDDO
               ENDDO
               if(grib=="grib2")then
                  cfld=cfld+1
                  fld_info(cfld)%ifld=IAVBLFLD(IGET(472))
                  fld_info(cfld)%lvl=LVLSXML(L,IGET(472))
!$omp parallel do private(i,j,ii,jj)
                  do j=1,jend-jsta+1
                     jj = jsta+j-1
                     do i=1,iend-ista+1
                       ii = ista+i-1
                       datapd(i,j,cfld) = GRID1(ii,jj)
                     enddo
                  enddo
               endif

            ENDIF
         end do
      end IF

! COMPUTE NCAR FIP
      IF(IGET(450)>0 .or. IGET(480)>0 .or. IGET(479)>0 .or. IGET(481)>0)THEN

!       cape and cin
        ITYPE  = 1
        DPBND  = 300.E2
        dummy  = 0.
        idummy = 0
        CALL CALCAPE(ITYPE,DPBND,dummy,dummy,dummy,idummy,cape,cin, &
                     dummy,dummy,dummy)

        icing_gfip = spval
        icing_gfis = spval
        DO J=JSTA,JEND
          DO I=ista,iend
            if(debugprint .and. i==50 .and. j==jsta .and. me == 0) then
              print*,'sending input to FIP ',i,j,lm,gdlat(i,j),gdlon(i,j),  &
                    zint(i,j,lp1),cprate(i,j),prec(i,j),avgcprate(i,j),cape(i,j),cin(i,j)
              do l=1,lm
                if(debugprint)print*,'l,P,T,RH,CWM,QQW,QQI,QQR,QQS,QQG,OMEG',&
                     l,pmid(i,j,l),t(i,j,l),rh3d(i,j,l),cwm(i,j,l),     &
                     q(i,j,l),qqw(i,j,l),qqi(i,j,l), &
                     qqr(i,j,l),qqs(i,j,l),qqg(i,j,l),&
                     rh3d(i,j,l),zmid(i,j,l),cwm(i,j,l),omga(i,j,l)
              end do
            end if
            CALL ICING_ALGO(i,j,pmid(i,j,1:lm),T(i,j,1:lm),RH3D(i,j,1:lm)   &
                ,ZMID(i,j,1:lm),OMGA(i,j,1:lm),wh(i,j,1:lm)   &
                ,q(i,j,1:lm),CWM(I,J,1:lm),qqw(i,j,1:lm),qqi(i,j,1:lm)   &
                ,qqr(i,j,1:lm),qqs(i,j,1:lm),qqg(i,j,1:lm)    &
                ,lm,gdlat(i,j),gdlon(i,j),zint(i,j,lp1)                     &
                ,prec(i,j),cprate(i,j),cape(i,j),cin(i,j)                &
                ,icing_gfip(i,j,1:lm),icing_gfis(i,j,1:lm))
!           if(gdlon(i,j)>=274. .and. gdlon(i,j)<=277. .and.  gdlat(i,j)>=42. &
!           .and. gdlat(i,j)<=45.)then
!            print*,'sample FIP profile: l, H, T, RH, CWAT, VV, ICE POT at '  &
!            , gdlon(i,j),gdlat(i,j)
!            do l=1,lm
!             print*,l,zmid(i,j,l),T(i,j,l),rh3d(i,j,l),cwm(i,j,l)  &
!             ,omga(i,j,l),icing_gfip(i,j,l),icing_gfis(i,j,l)
!            end do
!           end if
          ENDDO
        ENDDO
! Chuang: Change to output isobaric NCAR icing
!	do l=1,lm
!      if(LVLS(L,IGET(450))>0 .or. LVLS(L,IGET(480))>0)then
!	  do j=jsta,jend
!	   do i=ista,iend
!	     grid1(i,j)=icing_gfip(i,j,l)
!	   end do
!	  end do   
!          ID(1:25) = 0
!          CALL GRIBIT(IGET(450),L,GRIDista,iend,JM)
!	 end if
!	end do  
      ENDIF

      DEALLOCATE(EL, RICHNO, PBLRI)
      if (allocated(rh3d)) deallocate(rh3d)
!     
!     END OF ROUTINE.
!     
      RETURN
      END
