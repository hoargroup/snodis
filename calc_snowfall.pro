;---------------------------------------------------------------------------------
; $Id: calc_snowfall.pro,v 1.12 2012/10/29 23:17:12 bguan Exp $
; Calculate snowfall from downscaled NLDAS precip and sat for input to SNODIS.
; This procedure partitions precip into snow, rain, or mixed, based on sat thresholds.
;
; Note: Both input and output files have missing values over oceans.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_snowfall

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
precip_in_file='precip.dat'; input file name for precip.
sat_in_file='sat.dat'; input file name for sat.

out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_file='snowfall.dat'; output file name for snowfall.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_snowfall...'

num_forcing_step=(julday(nldas_last_month,nldas_last_day,year)-julday(1,1,year)+1)*24/time_step

; mixed precip threshold values (degC) taken from U.S. Army Corps of Engineers (1956, plate 3-1).
tr=3.0; above which all precip is assumed to be rain [degC].
ts=-1.0; below which all precip is assumed to be snow [degC].

openr,1,in_dir+precip_in_file
precip_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

openr,2,in_dir+sat_in_file
sat_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

openw,3,out_dir+out_file
snowfall_cube=assoc(3,fltarr(ncols_snodis,nrows_snodis))

for i=0,num_forcing_step-1 do begin

   print,string(i+1,num_forcing_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_snowfall...")')
 
   precip=precip_cube[i]; [mm]
   tmp_index=where(precip eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then precip(tmp_index)=!values.f_nan
 
   sat_degC=sat_cube[i]-273.15; [degC].
   tmp_index=where(sat_degC eq undefi-273.15,tmp_cnt)
   if tmp_cnt ne 0 then sat_degC(tmp_index)=!values.f_nan
 
   snow_mask=replicate(0.0,ncols_snodis,nrows_snodis); re-initialize snow mask each time step.
   rain_mask=replicate(0.0,ncols_snodis,nrows_snodis); re-initialize snow mask each time step.
   mix_mask=replicate(1.0,ncols_snodis,nrows_snodis); re-initialize snow mask each time step. 
 
   ; mask where all precip is rain.
   tmp_index=where(sat_degC gt tr,tmp_cnt)
   if tmp_cnt ne 0 then rain_mask[tmp_index]=1.0
 
   ; mask where all precip is snow.
   tmp_index=where(sat_degC lt ts,tmp_cnt)
   if tmp_cnt ne 0 then snow_mask[tmp_index]=1.0
 
   ; mask where precip is mixed. mix_mask=1.0 where ts<=sat_degC<=tr and 0.0 elsewhere.
   mix_mask=mix_mask-snow_mask-rain_mask
 
   ; compute grid of mixed precip, which has non-zero values only at locations where mix_mask=1.
   snow_mixed=(precip*(tr-sat_degC)/(tr-ts))*mix_mask; liquid water equivalent of snow among mixed precip.
 
   snowfall=precip*snow_mask+snow_mixed; liquid water equivalent of incremental snow fall at all pixels.
 
   tmp_index=where(~finite(snowfall),tmp_cnt)
   if tmp_cnt ne 0 then snowfall(tmp_index)=undefo; replace NaN's with undefo for file output.
   snowfall_cube[i]=snowfall;
 
endfor

close,1,2,3

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+in_dir+'precip.dat '+in_dir+'sat.dat'

print,'[SNODIS info] ended running calc_snowfall.'
end

; References
;
; U.S. Army Corps of Engineers (1956). Snow hydrology: Summary report of the snow investigations.
; North Pacific Division, Portland, OR, 437 p.
