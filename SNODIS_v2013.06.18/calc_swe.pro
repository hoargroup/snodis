;---------------------------------------------------------------------------------
; $Id: calc_swe.pro,v 1.12 2012/10/29 23:17:12 bguan Exp $
; Calculate SWE.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_swe

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
in_file='cummelt.dat'

out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_file='swe.dat'

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_swe...'

num_snodis_step=(julday(last_month,last_day,year)-julday(first_month,first_day,year)+1)*24/time_step

openr,1,in_dir+in_file
cummelt_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))
openw,2,out_dir+out_file
swe_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))
cummelt_grid=fltarr(ncols_snodis,nrows_snodis)

swe0=cummelt_cube[num_snodis_step-1];
tmp_index=where(swe0 eq undefi,tmp_cnt)
if tmp_cnt ne 0 then swe0(tmp_index)=!values.f_nan

for i=0,num_snodis_step-1 do begin
   print,string(i+1,num_snodis_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_swe...")')
   cummelt_grid=cummelt_cube[i]
   tmp_index=where(cummelt_grid eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then cummelt_grid(tmp_index)=!values.f_nan
   swe=swe0-cummelt_grid
   tmp_index=where(~finite(swe),tmp_cnt)
   if tmp_cnt ne 0 then swe(tmp_index)=0.0; set NaN's to zeros for file output (NaN's are only present over ocean, due to NLDAS).
   swe_cube[i]=swe
endfor

close,1,2

output,'swe'

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+in_dir+'cummelt.dat '+in_dir+'swe.dat'

print,'[SNODIS info] ended running calc_swe.'
end
