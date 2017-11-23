;---------------------------------------------------------------------------------
; $Id: calc_turblong.pro,v 1.23 2012/12/14 20:57:49 bguan Exp $
; Calculate turbulent heat and longwave radiation fluxes.
;
; Note 1: Input NLDAS-based files (sat, windspeed, and relhum) DO have missing values over the oceans.
; Note 2: Input forden may have value 1.0 at certain places, which will NOT be adjusted in this procedure.
; Note 3: forden has value 0 over the oceans as of this version.
; Note 4: There are num_snodis_step layers in output files.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_turblong,turbulent_scheme,longwave_scheme

common param

sat_in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
sat_in_file='sat.dat'; input file name.

windspeed_in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
windspeed_in_file='windspeed.dat'; input file name.

relhum_in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
relhum_in_file='relhum.dat'; input file name.

forden_in_dir=snodis_root+'input_static/'+area+'/'; DO include trailing slash.
forden_in_file='forden.dat'; input file name.

turbulent_out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
turbulent_out_file='turbulent.dat'; output file name.

longup_out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
longup_out_file='longup.dat'; output file name.

longdown_out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
longdown_out_file='longdown.dat'; output file name.

sat_nldas_in_dir=snodis_root+'input_meto/'+area+'/'+strcompress(year,/remove_all)+'/'; DO include trailing slash.
sat_nldas_in_file='sat.dat'; input file name.

dlwrf_nldas_in_dir=snodis_root+'input_meto/'+area+'/'+strcompress(year,/remove_all)+'/'; DO include trailing slash.
dlwrf_nldas_in_file='dlwrf.dat'; input file name.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_turblong...'

iregrid_multiple=ncols_snodis/ncols_nldas
jregrid_multiple=nrows_snodis/nrows_nldas

num_snodis_step=(julday(last_month,last_day,year)-julday(first_month,first_day,year)+1)*24/time_step
offset_start=(julday(first_month,first_day,year,0)-julday(1,1,year,0))*24.0/time_step; number of layers to skip between 00:00 Jan-01 and first model step.

; constants for turbulent flux calculations as per Jordan (1991; p. 27--29).
c_air=1005.0; specific heat capacity of air at constant pressure [J kg^-1 K^-1].
E_C0=2.0; windless turbulent heat exchange coefficient [W m^-2].
L_vi=2.838e+6; latent heat of ice sublimation [J kg^-1].
rho_air=1.276; air density at 0 degC and 1 bar, assumed constant [kg m^-3].
R_w=461.296; gas constant for water vapor [J kg^-1 K^-1].
z_0=0.0005; rougness length (Molotch et al. 2008) [m].
Z_Q=2.0; measurement height of relative humidity [m].
Z_T=2.0; measurement height of temperature [m].
Z_W=10.0; measurement height of wind speed [m].

; open data cube to read sat.
openr,1,sat_in_dir+sat_in_file
sat_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

; open data cube to read windspeed.
openr,2,windspeed_in_dir+windspeed_in_file
windspeed_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

; open data cube to read relhum.
openr,3,relhum_in_dir+relhum_in_file
relhum_cube=assoc(3,fltarr(ncols_snodis,nrows_snodis))

; read forden.
forden_grid=fltarr(ncols_snodis,nrows_snodis)
if file_test(forden_in_dir+forden_in_file) then begin
openr,4,forden_in_dir+forden_in_file
readu,4,forden_grid
close,4
endif

; open data cube to write turbulent (i.e., sensible + latent).
openw,66,turbulent_out_dir+turbulent_out_file
turbulent_cube=assoc(66,fltarr(ncols_snodis,nrows_snodis))

; open data cube to write longup.
openw,7,longup_out_dir+longup_out_file
longup_cube=assoc(7,fltarr(ncols_snodis,nrows_snodis))

; open data cube to write longdown.
openw,8,longdown_out_dir+longdown_out_file
longdown_cube=assoc(8,fltarr(ncols_snodis,nrows_snodis))

; open data cube to read NLDAS sat.
openr,9,sat_nldas_in_dir+sat_nldas_in_file
sat_nldas_cube=assoc(9,fltarr(ncols_nldas,nrows_nldas))

; open data cube to read NLDAS dlwrf.
openr,10,dlwrf_nldas_in_dir+dlwrf_nldas_in_file
dlwrf_nldas_cube=assoc(10,fltarr(ncols_nldas,nrows_nldas))

; define constants related to water vapor pressure calculations.
ones_array=replicate(1.0,ncols_snodis,nrows_snodis)
u_grid=9.5D*ones_array; u-value from Tetens (1930) in Murray (1967) for ice.
v_grid=265.5D*ones_array ; v-value from Tetens (1930) in Murray (1967) for ice.
w_grid=0.7858D*ones_array; w-value from Tetens (1930) in Murray (1967).

snowemiss=0.98; assumed snow emissivity.

for i=0,num_snodis_step-1 do begin; main loop.
print,string(i+1,num_snodis_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_turblong...")')

sat_grid=sat_cube[i+offset_start]
tmp_index=where(sat_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then sat_grid(tmp_index)=!values.f_nan

; estimate snow surface temperature using an assumed lag time behind sat. Cline and Carroll (1999, p. 19,632) assumed 1-hr lag time. Molotch et al. (2008) assumed 2-hr lag time.
sst_lag=1.0; [hour]
sst_grid=sat_cube[max([0,i+offset_start-sst_lag/time_step])]
tmp_index=where(sst_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then sst_grid(tmp_index)=!values.f_nan
tmp_index=where(sst_grid-273.15 gt 0.0,tmp_cnt)
if tmp_cnt ne 0 then sst_grid(tmp_index)=273.15; prevent sst from exceeding zero degC (273.15 K).

windspeed_grid=windspeed_cube[i+offset_start]
tmp_index=where(windspeed_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then windspeed_grid(tmp_index)=!values.f_nan

relhum_grid=relhum_cube[i+offset_start]
tmp_index=where(relhum_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then relhum_grid(tmp_index)=!values.f_nan

; create bulk Richardson number grid from Eqn. 98 in Jordan (1991).
Ri=fltarr(ncols_snodis,nrows_snodis); initialize to zeros.
tmp_index=where(windspeed_grid ne 0,tmp_cnt); indices where wind speed is NOT 0, including where windspeed is undefined.
if tmp_cnt ne 0 then begin
   Ri[tmp_index]=9.8*Z_T*(sat_grid[tmp_index]-sst_grid[tmp_index])*(0.5*(sat_grid[tmp_index]+sst_grid[tmp_index])*(windspeed_grid[tmp_index])^2)^(-1); note: Ri is undefined where windspeed is so.
endif

; impose limits on bulk Richardson number. Only use one of the following blocks.
; block 1:
; impose lower and upper limits on Richardson number to follow the convention of the original 'calc_turb.pro' file from Noah Molotch care of Aldo Flores.
;index=where(Ri lt -1.0,count)
;if count ne 0 then Ri[index]=-1.0; impose lower limit on Ri, why not sure.
;index=where(Ri gt 0.19,count)
;if count ne 0 then Ri[index]=0.19; impose upper limit on Ri, probably to effectively suppress turbulent exchange in highly stable conditions where Ri>~0.2 (Jordan, 1991). 
; block 2:
; force negligible turbulent exchange when Ri>0.2 as per Jordan (1991) Eqn. 97c.  
tmp_index=where(Ri gt 0.1999,tmp_cnt)
if tmp_cnt ne 0 then Ri[tmp_index]=0.1999

; define regions of turbulent stability. 
index_stable=where(Ri gt 0.0,count_stable); pixels with stable turbulent conditions (i.e. mechanically induced turbulence).
index_neutral=where(Ri eq 0.0,count_neutral)
index_unstable=where(Ri lt 0.0,count_unstable); pixels with unstable turbulent conditions (i.e. thermally induced turbulence).
; note: indices where Ri is undefined are not contained in the above three arrays.

; initialize the stability function grids (to NaN's, so that they are undefined where Ri is so) and populate as per Jordan (1991) p. 28.
phi_m=replicate(!values.f_nan,ncols_snodis,nrows_snodis) 
phi_e=replicate(!values.f_nan,ncols_snodis,nrows_snodis)
phi_h=replicate(!values.f_nan,ncols_snodis,nrows_snodis)
if count_stable ne 0 then begin
   phi_m[index_stable]=(1.0-5.0*Ri[index_stable])^(-1)
   phi_e[index_stable]=phi_m[index_stable]
   phi_h[index_stable]=phi_m[index_stable] 
endif
if count_neutral ne 0 then begin
   phi_m[index_neutral]=1.0
   phi_e[index_neutral]=1.0
   phi_h[index_neutral]=1.0
endif
if count_unstable ne 0 then begin
   phi_m[index_unstable]=(1.0-16.0*Ri[index_unstable])^(-0.25) 
   phi_e[index_unstable]=(1.0-16.0*Ri[index_unstable])^(-0.5) 
   phi_h[index_unstable]=phi_e[index_unstable]
   ; below is the original approach in 'calc_turb.pro'.
   ;phi_m[index_unstable]=(1.0-5.0*Ri[index_unstable])^(-1)
   ;phi_e[index_unstable]=phi_m[index_unstable]
   ;phi_h[index_unstable]=phi_m[index_unstable]
endif

; neutral stability drag coefficient.
C_DN=(0.4/alog(Z_w/z_0))^2; C_DN in Jordan (1991) p. 27.

; bulk transfer coefficient grids as per Jordan (1991) p. 27.
C_E=C_DN*(phi_m*phi_e*(1.0+alog(Z_Q/Z_W)/alog(Z_W/z_0)))^(-1)
C_H=C_DN*(phi_m*phi_h*(0.7+alog(Z_T/Z_W)/alog(Z_W/z_0)))^(-1)

; calculate water vapor pressure [hPa] at snow surface (assuming relhum=1) using Teten's Equation (Murray, 1967).
; note: take care of phsyical limits on sst before use.
surf_vappress=10.0D^(w_grid+((sst_grid-273.15)*u_grid)/((sst_grid-273.15)+v_grid))

; calculate water vapor pressure [hPa] at reference height using Teten's Equation (Murray, 1967).
tmp_index=where(sat_grid-273.15 gt 0.0,tmp_cnt)
if tmp_cnt ne 0 then begin
   u_grid[tmp_index]=7.5D
   v_grid[tmp_index]=237.3D
endif
air_vappress=relhum_grid*10.0D^(w_grid+((sat_grid-273.15)*u_grid)/((sat_grid-273.15)+v_grid))
 
if turbulent_scheme eq 'SENLAT' then begin
;---------------------------------------------------------------------------------
; method 1: SENLAT.
;---------------------------------------------------------------------------------
sensible_grid=(E_C0+rho_air*c_air*C_H*windspeed_grid)*(sat_grid-sst_grid); calculate turbulent fluxes of sensible and latent heat using Eqn. 93 in Jordan (1991).
E_E=(100.0*L_vi/R_w)*C_E*sat_grid^(-1) 
latent_grid=(E_C0+E_E*windspeed_grid)*(air_vappress-surf_vappress); using water vapor pressure at sst.
;latent_grid=(E_C0+E_E*windspeed_grid)*(air_vappress-6.11); using saturation water vapor pressure at 0 degC. 
turbulent_grid=sensible_grid+latent_grid
endif
if turbulent_scheme eq 'DEGDAY' then begin
;---------------------------------------------------------------------------------
; method 2: DEGDAY (for test).
;---------------------------------------------------------------------------------
degday_coeff=0.15; (Molotch and Margulis 2008 used 0.15)
my_coeff=(degday_coeff/100.0/(24.0*3600.0))/(1.0/(1000.0*3.34E5)); degC to W m^-2 conversion coefficient.
turbulent_grid=(sat_grid-273.15)*my_coeff
endif

;---------------------------------------------------------------------------------
; done with turbulence.
;---------------------------------------------------------------------------------

; compute downwelling longwave radiation.
if longwave_scheme eq 'IDSO' then begin
;---------------------------------------------------------------------------------
; method 1: IDSO (original).
;---------------------------------------------------------------------------------
airemiss=0.7+(5.95e-5)*air_vappress*exp(1500.0*(sat_grid+0.0)^(-1)); air emissivity from Idso (1981).
corrairemiss=-0.792+3.161*airemiss-1.573*airemiss^2; "Wachtmann correction" to air emissivity (Hodges et al. 1983, eqn. 20).
forairemiss=corrairemiss*(1.0-forden_grid)+0.98*forden_grid; forest canopy correction to air emissivity (Cline and Carroll 1999, eqn. 2).
longdown_grid=5.6704e-8*forairemiss*(sat_grid)^4; downwelling longwave radiation [W m^-2].
endif
if longwave_scheme eq 'NLDAS' then begin
;---------------------------------------------------------------------------------
; method 2: NLDAS.
;---------------------------------------------------------------------------------
airemiss=fltarr(ncols_snodis,nrows_snodis); declare so that it can be subscripted.
sat_nldas_grid=sat_nldas_cube(i+offset_start)
tmp_index=where(sat_nldas_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then sat_nldas_grid(tmp_index)=!values.f_nan
dlwrf_nldas_grid=dlwrf_nldas_cube(i+offset_start)
tmp_index=where(dlwrf_nldas_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then dlwrf_nldas_grid(tmp_index)=!values.f_nan
airemiss_istart=0
airemiss_jstart=0
for nldasj=0,nrows_nldas-1 do begin
    for nldasi=0,ncols_nldas-1 do begin
    sat_nldas_point=sat_nldas_grid(nldasi,nldasj)
    dlwrf_nldas_point=dlwrf_nldas_grid(nldasi,nldasj)
    airemiss_nldas_point=dlwrf_nldas_point/(5.6704e-8*sat_nldas_point^4)
    airemiss_i=airemiss_istart+nldasi*iregrid_multiple
    airemiss_j=airemiss_jstart+nldasj*jregrid_multiple
    airemiss(airemiss_i:airemiss_i+iregrid_multiple-1,airemiss_j:airemiss_j+jregrid_multiple-1)=airemiss_nldas_point
    endfor
endfor
forairemiss=airemiss*(1.0-forden_grid)+0.98*forden_grid; forest canopy correction to air emissivity (Cline and Carroll 1999, eqn. 2).
longdown_grid=5.6704e-8*forairemiss*(sat_grid)^4; downwelling longwave radiation [W m^-2].
endif

; compute upwelling longwave radiation.
longup_grid=5.6704e-8*snowemiss*(sst_grid)^4; upwelling longwave radiation [W m^-2].

;---------------------------------------------------------------------------------
; output to files.
;---------------------------------------------------------------------------------
tmp_index=where(~finite(turbulent_grid),tmp_cnt)
if tmp_cnt ne 0 then turbulent_grid(tmp_index)=undefo; replace NaN's with undefo for file output.
tmp_index=where(~finite(longup_grid),tmp_cnt)
if tmp_cnt ne 0 then longup_grid(tmp_index)=undefo; replace NaN's with undefo for file output.
tmp_index=where(~finite(longdown_grid),tmp_cnt)
if tmp_cnt ne 0 then longdown_grid(tmp_index)=undefo; replace NaN's with undefo for file output.
turbulent_cube[i]=turbulent_grid
longup_cube[i]=longup_grid
longdown_cube[i]=longdown_grid

endfor; end main loop.

close,1,2,3,4,66,7,8,9,10

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+windspeed_in_dir+'windspeed.dat '+relhum_in_dir+'relhum.dat'

print,'[SNODIS info] ended running calc_turblong.'
end

; References
; 
; Cline, D.W. and T.R. Carroll (1999). Inference of snow cover beneath obscuring clouds 
; using optical remote sensing and a distributed snow energy and mass balance model. 
; Journal of Geophysical Research, 104(D16), 19,631-19,644.
; 
; Hodges, D.B., G.J. Higgins, P.F. Hilton, R.E. Hood, R. Shapiro, et al. (1983). Final 
; tactical decision aid (FTDA) for infrared (8-12 micron) systems-technical background. 
; Scientific Report No. 5, Air Force Geophysics Laboratory.
; 
; Idso, S.B. (1981). A set of equations for full spectrum and 8- to 14-micron and 10.5- to 
; 12.5-micron thermal radiation from cloudless skies. Water Resources Research, 17(2), 
; 295-304, 295-304.
; 
; Jordan, R. (1991). A one-dimensional temperature model for a snow cover. 
; CRREL Special Report 91-16.
; 
; Murray, F.W. (1967). On the computation of saturation vapor pressure. Journal of Applied 
; Meteorology, 6, 203-204.
