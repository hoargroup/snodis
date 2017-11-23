;---------------------------------------------------------------------------------
; $Id: calc_relhum.pro,v 1.14 2012/10/29 23:17:12 bguan Exp $
; Calculate relhum from downscaled NLDAS spehum, sat and ps for input to SNODIS.
;
; Note: Both input and output files have missing values over oceans.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_relhum

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
spehum_in_file='spehum.dat'; input file name for spehum.
sat_in_file='sat.dat'; input file name for sat.
ps_in_file='ps.dat'; input file name for ps.

out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_file='relhum.dat'; output file name for relhum.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_relhum...'

num_forcing_step=(julday(nldas_last_month,nldas_last_day,year)-julday(1,1,year)+1)*24/time_step

; physical constants.
M_H2O=18.01534; grams per mole of H2O.
M_dry=28.9644; grams per mole of dry air.

openr,1,in_dir+spehum_in_file
spehum_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

openr,2,in_dir+sat_in_file
sat_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

openr,3,in_dir+ps_in_file
ps_cube=assoc(3,fltarr(ncols_snodis,nrows_snodis))

openw,4,out_dir+out_file
relhum_cube=assoc(4,fltarr(ncols_snodis,nrows_snodis))

ones_array=replicate(1.0D,ncols_snodis,nrows_snodis)

for i=0,num_forcing_step-1 do begin

print,string(i+1,num_forcing_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_relhum...")')

sat_degC=sat_cube[i]-273.15; [degC].
tmp_index=where(sat_degC eq undefi-273.15,tmp_cnt)
if tmp_cnt ne 0 then sat_degC(tmp_index)=!values.f_nan

ps_hPa=ps_cube[i]/100.0; [hPa].
tmp_index=where(ps_hPa eq undefi/100.0,tmp_cnt)
if tmp_cnt ne 0 then ps_hPa(tmp_index)=!values.f_nan

spehum=spehum_cube[i]; [kg/kg].
tmp_index=where(spehum eq undefi,tmp_cnt)
if tmp_cnt ne 0 then spehum(tmp_index)=!values.f_nan

; more constants.
u_grid=7.5D*ones_array; u-value from Tetens (1930) in Murray (1967).
v_grid=237.3D*ones_array; v-value from Tetens (1930) in Murray (1967).
index_freeze=where(sat_degC le 0.0,count_freeze)
if(count_freeze ne 0) then begin
u_grid[index_freeze]=9.5D; u-value from Tetens (1930) in Murray (1967).
v_grid[index_freeze]=265.5D; v-value from Tetens (1930) in Murray (1967).
endif
w_grid=0.7858D*ones_array; w-value from Tetens (1930) in Murray (1967).
 
satwvp=10.0D^(w_grid+(sat_degC*u_grid)/(sat_degC+v_grid)); saturation water vapor pressure based on Teten's equation in Murray (1967) [hPa].
 
x_H2O=M_dry*spehum/(M_dry*spehum+M_H2O*(1-spehum)); mole fraction: mole of H2O per mole of moist air (Cactus2000) [non-dimensional].
 
wvp=x_H2O*ps_hPa; water vapor pressure [hPa].
 
relhum=wvp/satwvp; [0--1 and non-dimensional].
 
tmp_index=where(relhum lt 0.0,tmp_cnt)
if tmp_cnt ne 0 then relhum[tmp_index]=0.0

tmp_index=where(relhum gt 1.0,tmp_cnt)
if tmp_cnt ne 0 then relhum[tmp_index]=1.0

tmp_index=where(~finite(relhum),tmp_cnt)
if tmp_cnt ne 0 then relhum(tmp_index)=undefo; replace NaN's with undefo for file output.
relhum_cube[i]=relhum 
 
endfor

close,1,2,3,4

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+in_dir+'ps.dat '+in_dir+'spehum.dat'

print,'[SNODIS info] ended running calc_relhum...'
end

; References
; 
; Cactus2000, Air humidity calculation (http://www.cactus2000.de), downloaded from 
; http://www.cactus2000.de/js/calchum.pdf on 05 Mar 2009.
; 
; Murray, F.W. (1967). On the computation of saturation vapor pressure. Journal of Applied 
; Meteorology, 6, 203-204.
