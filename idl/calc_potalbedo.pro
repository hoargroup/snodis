;---------------------------------------------------------------------------------
; $Id: calc_potalbedo.pro,v 1.13 2012/10/29 23:17:12 bguan Exp $
; Compute potential albedo (i.e. albedo if there is snow everywhere within a pixel).
; In this procedure we assume that the Sun position has no effect on snow albedo.
; We do not make this assumption for albedos used explicitely in the energy balance of snow.
;
; Note 1: There are num_snodis_step layers in the output file, unlike in snowfall.dat.
; Note 2: Both input and output files have missing values over oceans.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_potalbedo,albedo_scheme

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
in_file='snowfall.dat'; input file name.

out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_file='potalbedo.dat'; output file name.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_potalbedo...'

num_forcing_step=(julday(nldas_last_month,nldas_last_day,year)-julday(1,1,year)+1)*24/time_step
offset_start=(julday(first_month,first_day,year,0)-julday(1,1,year,0))*24.0/time_step; number of layers to skip between 00:00 Jan-01 and first model step.

; open data cube to read snowfall.
openr,1,in_dir+in_file
snowfall_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

; open data cube for writing to.
openw,2,out_dir+out_file
potalbedo_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

if albedo_scheme eq 'BATS' then begin
;---------------------------------------------------------------------------------
; method 1: BATS (original).
;---------------------------------------------------------------------------------
; define BATS model constants (Dickinson et al., 1993).
alpha_iro=0.65
alpha_vo=0.95
b=2.0
c_n=0.5
c_s=0.2
frac_solar_vis=0.47; fraction of solar power at wavelengths <0.7 micron.
frac_solar_ir=(1.0-frac_solar_vis); fraction of solar power at wavelengths >0.7 micron.
T_g1=273.15; assumed soil surface temperature during melt season (K).

; define derived parameters/constants.
time_step=1.0; model time step [hour].
num_sec_per_hour=3600.0;
time_step_sec=time_step*num_sec_per_hour; model time step [second].
r_1=exp(5000*((1/273.16)-(1/T_g1)))
r_2=min([r_1^10,1.0])
r_3=0.3
delta_tau_snow=(1.0e-6)*(r_1+r_2+r_3)*time_step_sec; snow age increment [non-dimensional]. 

; initialize snow age to zero.
tau_snow_old=replicate(0.0,ncols_snodis,nrows_snodis); [non-dimensional]

for i=0,num_forcing_step-1 do begin
    print,string(i+1,num_forcing_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_potalbedo...")')

    snowfall=snowfall_cube[i]; snowfall during this time step.
    tmp_index=where(snowfall eq undefi,tmp_cnt)
    if tmp_cnt ne 0 then snowfall(tmp_index)=!values.f_nan
    tau_snow=(tau_snow_old+delta_tau_snow)*(1.0-0.1*snowfall); updated snow age; 10 mm liquid water equivalent of snow resets snow age to zero (Dickinson et al., 1993).
    tmp_index=where(tau_snow lt 0.0,tmp_cnt)
    if tmp_cnt ne 0 then tau_snow[tmp_index]=0.0; prevent snow age from becoming negative. 

    ; compute the snow albedo based on the current snow age.
    f_age=tau_snow/(1.0+tau_snow)
    alph_vd=alpha_vo*(1.0-c_s*f_age)
    alph_ird=alpha_iro*(1.0-c_n*f_age)
    alph_v=alph_vd; assume f=0 in Dickinson et al. (1993).
    alph_ir=alph_ird; assume f=0 in Dickinson et al. (1993).
    alph=alph_v*frac_solar_vis+alph_ir*frac_solar_ir; all-wave potalbedo.
    tmp_index=where(~finite(alph),tmp_cnt)
    if tmp_cnt ne 0 then alph(tmp_index)=undefo; replace NaN's with undefo for file output.
    if i ge offset_start then potalbedo_cube[i-offset_start]=alph; output from 1st MODEL step.
    tau_snow_old=tau_snow
endfor
endif
if albedo_scheme eq 'USACE' then begin
;---------------------------------------------------------------------------------
; method 2: USACE.
;---------------------------------------------------------------------------------
; initialize snow age to zero.
tau_snow=replicate(0.0,ncols_snodis,nrows_snodis); [day]

for i=0,num_forcing_step-1 do begin
    print,string(i+1,num_forcing_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_potalbedo_USACE...")')

    tau_snow=tau_snow+time_step/24.0; [day]
    snowfall=snowfall_cube[i]; snowfall during this time step.
    tmp_index=where(snowfall eq undefi,tmp_cnt)
    if tmp_cnt ne 0 then snowfall(tmp_index)=!values.f_nan
    tmp_index=where(snowfall gt 10,tmp_cnt)
    if tmp_cnt ne 0 then tau_snow(tmp_index)=0; updated snow age; 10 mm liquid water equivalent of snow resets snow age to zero (USACE, 1956).
    tmp_index=where(tau_snow gt 49,tmp_cnt)
    if tmp_cnt ne 0 then tau_snow(tmp_index)=49; prevent snow age from becoming greater than 49. 

    ; compute the snow albedo based on the current snow age.
    alph=0.00001*tau_snow^4-0.0007*tau_snow^3+0.0116*tau_snow^2-0.0965*tau_snow+0.8124
    tmp_index=where(alph lt 0.5,tmp_cnt)
    if tmp_cnt ne 0 then alph(tmp_index)=0.5; prevent albedo from becoming less than 0.5.
    tmp_index=where(~finite(alph),tmp_cnt)
    if tmp_cnt ne 0 then alph(tmp_index)=undefo; replace NaN's with undefo for file output.
    if i ge offset_start then potalbedo_cube[i-offset_start]=alph; output from 1st MODEL step.
endfor
endif

close,1,2

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+in_dir+'snowfall.dat'

print,'[SNODIS info] ended running calc_potalbedo.'
end

; References
; 
; Dickinson, R.E., A. Henderson-Sellers and P.J. Kennedy (1993). Biosphere-Atmosphere Transfer
; Scheme (BATS) Version 1e as coupled to the NCAR Community Climate Model. NCAR Technical Note 
; NCAR/TN-387+STR, National Center for Atmospheric Research, Boulder, CO.
;
; U.S. Army Corps of Engineers (1956), Snow Hydrology: Summary Report of the Snow Investigations,
; 462 pp., North Pac. Div., Portland, Oreg.
