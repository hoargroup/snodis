;---------------------------------------------------------------------------------
; $Id: calc_energy.pro,v 1.20 2012/11/14 00:53:50 bguan Exp $
; Calculate hourly energy fluxes.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_energy

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.

out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_energy...'

; read forden (cannot have missing values).
; forden is used (1) in prepare_fsca_fscamask.pro to apply vgf-correction, (2) in calc_turblong.pro, and (3) here to scale incoming solar radiation with forsol_coeff.
forden_in_dir=snodis_root+'input_static/'+area+'/'; DO include trailing slash.
forden_in_file='forden.dat'; input file name.
forden=fltarr(ncols_snodis,nrows_snodis); [0--1 non-dimensional]
if file_test(forden_in_dir+forden_in_file) then begin
openr,1,forden_in_dir+forden_in_file
readu,1,forden
close,1
endif
forsol_coeff=0.01*exp(4.605-3.0*forden); forest canopy solar transmission coefficient (Cline and Carrol 1999, eqn. 1) [0--1].

num_snodis_step=(julday(last_month,last_day,year)-julday(first_month,first_day,year)+1)*24/time_step
offset_start=(julday(first_month,first_day,year,0)-julday(1,1,year,0))*24.0/time_step; number of layers to skip between 00:00 Jan-01 and first model step.

; open input data cubes.
openr,12,in_dir+'turbulent.dat'
turbulent_cube=assoc(12,fltarr(ncols_snodis,nrows_snodis))
openr,14,in_dir+'longup.dat'
longup_cube=assoc(14,fltarr(ncols_snodis,nrows_snodis))
openr,15,in_dir+'longdown.dat'
longdown_cube=assoc(15,fltarr(ncols_snodis,nrows_snodis))
openr,16,in_dir+'topogoes.dat'
topogoes_cube=assoc(16,fltarr(ncols_snodis,nrows_snodis)); downscaled solar radiation [W m^-2].
openr,17,in_dir+'potalbedo.dat'
potalbedo_cube=assoc(17,fltarr(ncols_snodis,nrows_snodis)); potential albedo (including solar illumination angle correction if using BATS scheme).

; open output data cubes.
openw,53,out_dir+'netenergy.dat'; net energy flux to snow [W m^-2].
netenergy_cube=assoc(53,fltarr(ncols_snodis,nrows_snodis))
;openw,54,out_dir+'solardown.dat'; downwelling solar radiation to snow [W m^-2].
;solardown_cube=assoc(54,fltarr(ncols_snodis,nrows_snodis))
;openw,55,out_dir+'solarup.dat'; upwelling solar radiation FROM snow [W m^-2].
;solarup_cube=assoc(55,fltarr(ncols_snodis,nrows_snodis))

for i=0,num_snodis_step-1 do begin

   print,string(i+1,num_snodis_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_energy...")')

   turbulent=turbulent_cube[i]
   longup=longup_cube[i]
   longdown=longdown_cube[i]
   topogoes=topogoes_cube[i]
   potalbedo=potalbedo_cube[i]

   tmp_index=where(turbulent eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then turbulent(tmp_index)=!values.f_nan
   tmp_index=where(longup eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then longup(tmp_index)=!values.f_nan
   tmp_index=where(longdown eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then longdown(tmp_index)=!values.f_nan
   tmp_index=where(topogoes eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then topogoes(tmp_index)=!values.f_nan; no missing values.
   tmp_index=where(potalbedo eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then potalbedo(tmp_index)=!values.f_nan; no missing values.

   ; downscaled solar radiation after accounting for attenuation by forest canopy (Cline and Carrol 1999).
   topogoessubcan=topogoes*forsol_coeff; XXX is this still needed in the case of NLDAS solar input? i.e., is NLDAS solar already below the canopy?

   solardown=topogoessubcan
   solarup=potalbedo*topogoessubcan
   netsolar=solardown-solarup
   netlong=longdown-longup
   netenergy=netsolar+netlong+turbulent; net energy flux to snow [W m^-2].

   tmp_index=where(~finite(netenergy),tmp_cnt)
   if tmp_cnt ne 0 then netenergy(tmp_index)=undefo; replace NaN's with undefo for file output.

   ; write to data cubes.
   netenergy_cube[i]=netenergy

endfor

close,12,13,14,15,16,17,53

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+in_dir+'turbulent.dat '+in_dir+'longup.dat '+in_dir+'longdown.dat '+in_dir+'topogoes.dat '+in_dir+'potalbedo.dat'

print,'[SNODIS info] ended running calc_energy.'
end
