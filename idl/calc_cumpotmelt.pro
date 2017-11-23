;---------------------------------------------------------------------------------
; $Id: calc_cumpotmelt.pro,v 1.14 2012/10/29 23:16:07 bguan Exp $
; Calculate cummulative potential snow melt.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_cumpotmelt

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
in_file='netenergy.dat'; input file name.

out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_file='cumpotmelt.dat'

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_cumpotmelt...'

; constants for meltwater generation.
L_w=3.34E5; latent heat of fusion for water (Lide 2008) [J kg^-1].
rho_w=1000.0; density of water [kg m^-3].

num_snodis_step=(julday(last_month,last_day,year)-julday(first_month,first_day,year)+1)*24/time_step

; read back netenergy.
openr,1,in_dir+in_file
netenergy_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis)); net energy flux available for melting [W m^-2].

; open write-to data cubes.
openw,2,out_dir+out_file; cummulative potential snow melt [m].
cumpotmelt_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))
cumpotmelt=fltarr(ncols_snodis,nrows_snodis)

for i=0,num_snodis_step-1 do begin

   print,string(i+1,num_snodis_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_cumpotmelt...")')

   ;---------------------------------------------------------------------------------
   ; method 2: daily averaged netenergy is used to generate potential snow melt.
   ;---------------------------------------------------------------------------------
   model_day=floor(i/24.0); model day corresponding to this time step [integer].
   average_from=model_day*24.0; lower limit of cube layer for averaging.
   average_to=average_from+24.0-1.0; upper limit of cube layer for averaging.

   netenergy=fltarr(ncols_snodis,nrows_snodis); initialize daily averaged netnergy.
   netenergyave=fltarr(ncols_snodis,nrows_snodis); initialize daily averaged netnergy.
   potmelt=fltarr(ncols_snodis,nrows_snodis); initialize potential snow melt.

   for j=average_from,average_to do begin
   netenergy=netenergy_cube[j]
   tmp_index=where(netenergy eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then netenergy(tmp_index)=!values.f_nan
   netenergyave+=netenergy
   endfor
   netenergyave/=24.0; daily averaged netenergy [W m^-2].

   potmelt=netenergyave*(time_step*3600.0)*(rho_w*L_w)^(-1); potential snow melt for this time step [m].
   tmp_index=where(potmelt lt 0.0,tmp_cnt)
   if tmp_cnt ne 0 then potmelt[tmp_index]=0.0; prevent unphysical negative potential snow melt.

   cumpotmelt+=potmelt; cumpotmelt up to (inclusive) this time step [m].
   tmp_index=where(~finite(cumpotmelt),tmp_cnt)
   if tmp_cnt ne 0 then cumpotmelt(tmp_index)=undefo; replace NaN's with undefo for file output.
   cumpotmelt_cube[i]=cumpotmelt
endfor

close,1,2

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+in_dir+'netenergy.dat'

print,'[SNODIS info] ended running calc_cumpotmelt.'
end
