;---------------------------------------------------------------------------------
; $Id: main_UpperColoradoRiver.pro,v 1.9 2012/12/14 21:21:58 bguan Exp $
; Main program of SNODIS.
;
; Copyright (C) 2012. All rights reserved.
;---------------------------------------------------------------------------------
; start common block.
;---------------------------------------------------------------------------------

common param,year,first_month,first_day,last_month,last_day,fsca_first_month,fsca_first_day,fsca_last_month,fsca_last_day,time_step,overpass_time,$
       nldas_last_month,nldas_last_day,area,ncols_nldas,nrows_nldas,ncols_snodis,nrows_snodis,dem_lon_small,dem_lat_large,dem_pixelsize,$
       refelev,omega,gfactor,optdepth,undefi,undefo,snodis_root,run_name

;
; Mode 1: loop over years
;
;years=[2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012]
;for year_cnt=0,n_elements(years)-1 do begin
;year=years(year_cnt)
;run_name=''; can be empty
;
; Mode 2: one year only
;
;read,year,prompt='Enter year (YYYY):'
year=2005
run_name=''; initialize to string type
;read,run_name,prompt='Enter run name (can be empty):'

; date range of simulation.
first_month=3
first_day=1
last_month=8
last_day=31

; end date of NLDAS forcing to be calculated (all hourly fields before since Jan-01 will be calculated).
nldas_last_month=8
nldas_last_day=31

time_step=1.0; model/forcing time step [hour].

overpass_time=19.0; UTC time of MODIS overpass used for accurate representation of decimal doy (Terra equator overpass = 10:30am mean local time) [decimal hour].

; domain info.
area='UpperColoradoRiver'; name of model domain [single word].
ncols_nldas=65
nrows_nldas=86
ncols_snodis=1950
nrows_snodis=2580
dem_lon_small=-112.247916666667; center longitude of the westernmost pixel [degree].
dem_lat_large=43.7479166666667; center latitude of the northernmost pixel [degree].
dem_pixelsize=0.00416666666666667; [degree]

; constants for IPW elevrad.
refelev=2027.68; reference elevation (elevation of optical depth instrument); here taken as mean elevation of Upper Colorado River basin [m].
; note for Sierra Nevada: mean elevation based on SRTM2.1 = 1642.56 m (south of 38N = 1787.22 m; north of 38N = 1526.27 m).
; values below are for relatively clean atmosphere and are obtained from http://www.icess.ucsb.edu/~kwright/ipw/man1/gelevrad.html and http://www.icess.ucsb.edu/~kwright/ipw/man1/elevrad.html
omega=0.85; single scattering albedo [non-dimensional].
gfactor=0.55; scattering asymmetry factor.
optdepth=0.20; optical depth of atmosphere at reference elevation [non-dimensional].

; file i/o info.
undefi=-9999
undefo=-9999
snodis_root='./'; root dir of model.
;---------------------------------------------------------------------------------
; end common block.
;---------------------------------------------------------------------------------

; switches.
turbulent_scheme='SENLAT'; [SENLAT | DEGDAY]
longwave_scheme='NLDAS'; [IDSO | NLDAS] 
albedo_scheme='USACE'; [BATS | USACE]

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

run_started_at=systime(1); when simulation started. 

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

; call subroutines.
calc_nldas,'precip'
calc_nldas,'ps'
calc_nldas,'sat'
calc_nldas,'spehum'
calc_nldas,'windspeed'
calc_relhum
calc_turblong,turbulent_scheme,longwave_scheme
calc_snowfall
calc_potalbedo,albedo_scheme
prepare_fsca_fscamask,fsca_doy; never comment this line since fsca_doy is needed below.
prepare_interppt_doy_fsca,fsca_doy
calc_mixalbedo,fsca_doy
;prepare_ipw; takes a long time, but need to run only once for a certain domain.
run_ipw,albedo_scheme
calc_energy
calc_cumpotmelt
prepare_interppt_cumpotmelt,fsca_doy
calc_fsca_cummelt,fsca_doy
calc_swe

run_ended_at=systime(1); when simulation ended.
print,'Simulation finished successfully after ',string(((run_ended_at-run_started_at)/60.0),format='(F0.1)'),' minutes.'

; postprocess

;
; end loop over years; comment out this block if running for a single year.
;
;endfor; end loop over years.

end; end of program.
exit ; need exit command to shutdown IDL on beach

; References
; 
; Baldridge, A.M., S.J. Hook, C.I. Grove and G. Rivera (2009). The ASTER spectral library
; version 2.0. Remote Sensing of Environment, 113(4), 711-715.
; 
; Cline, D.W. and T.R. Carroll (1999). Inference of snow cover beneath obscuring clouds 
; using optical remote sensing and a distributed snow energy and mass balance model. 
; Journal of Geophysical Research, 104(D16), 19,631-19,644.
; 
; Dozier, J. (1989). Spectral signature of alpine snow cover from the Landsat 
; Thematic Mapper. Remote Sensing of Environment, 28, 9-22.
; 
; Erickson, T.A., M.W. Williams and A. Winstral (2005). Persistence of topographic 
; controls on the spatial distribution of snow in rugged mountain terrain, Colorado, 
; United States. Water Resources Research, 41, W04014, doi:10.1029/2003WR002973.
; 
; Jordan, R. (1991). A one-dimensional temperature model for a snow cover. 
; CRREL Special Report 91-16.
; 
; Lide, D. R. (Ed.) (2008), CRC Handbook of Chemistry and Physics, 88th
; ed., CRC Press, Boca Raton, Fla.
; 
; Marks, D., J. Dozier and R.E. Davis (1992). Climate and energy exchange at the 
; snow surface in the alpine region of the Sierra Nevada. 1. Meteorological 
; measurements and monitoring. Water Resources Research, 28(11), 3029-3042.
; 
; Meador, W.E. and W.R. Weaver (1980). Two-stream approximations to radiative transfer in 
; planetary atmospheres: a unified description of existing methods and a new improvement. 
; Journal of the Atmospheric Sciences, 37, 630-643.
; 
; Meixner, T., R.C. Bales, M.W. Williams, D.H. Campbell and J.S. Baron (2000). Stream chemistry 
; modeling of two watersheds in the Front Range, Colorado. Water Resources Research, 36(1), 77-87.
; 
; Molotch, N.P., T. Meixner and M.W. Williams (2008). Estimating stream chemistry 
; during the snowmelt pulse using a spatially distributed, coupled snowmelt and hydrochemical 
; modeling approach. Water Resources Research, 44, W11429, doi:10.1029/2007WR006587.
; 
; Tonnessen, K.A. (1991). The Emerald Lake watershed study: introduction and site 
; description. Water Resources Research, 27(7), 1537-1539.
; 
; Williams, M.W. and J.M. Melack (1991). Solute chemistry of snowmelt and runoff in an 
; alpine basin, Sierra Nevada. Water Resources Research, 27(7), 1575-1588.
;
; Notes:
; 
; 1. Albedo of rock and soil. The albedo of rock and soil is modeled after granite and granodiorite
; in the wavelength range of 0.4-2 micron, where most of the sun's energy occurs. Granite and granodiorite
; cover ~33% of the Emerald Lake watershed (Tonnessen, 1991; Williams and Melack, 1991), a small watershed
; in the southwest corner of Tokopah Basin, and granite covers ~30% of Green Lake 4 valley (Meixner
; et al., 2000; Erickson et al., 2005). The average hemispherical reflectance values (0.4-2 micron) of solid 
; granite and granodiorite in the ASTER library (http://speclib.jpl.nasa.gov/search-1/rock) range from 
; 9.8% to 28.8%. The average value is 19%. See C:\jepsen_work\2009-sem2\snow_postdoc\rock_reflectance 
; for the spreadsheets.    
