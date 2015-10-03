;---------------------------------------------------------------------------------
; $Id: postprocess.pro,v 1.27 2012/08/20 23:05:36 bguan Exp $
; Post-process daily model SWE (elevation threshold, watermask, residual correction).
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro postprocess

common param

;
; loop over years; comment out this block if running for a single year.
;
;years=[2000,2001,2002,2003,2004,2005,2006,2007,2008,2009]
;for year_cnt=0,n_elements(years)-1 do begin
;year=years(year_cnt)
print,string(year,format='("[SNODIS info] post-processing year ",I0,"...")')

snodis_swe_in_dir=snodis_root+'output/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
snodis_swe_in_file='swe.dat'; input file name.

cdec_swe_in_dir='/home/bguan/DATA/CDEC/SWE_Daily0000PT/'; DO include trailing slash.
cdec_swe_in_file='SWE_Daily0000PT_SNODISGridded.dat'; input file name.

dem_in_dir=snodis_root+'input_static/'+area+'/'; DO include trailing slash.
dem_in_file='dem.dat'; input file name.

watermask_in_dir=snodis_root+'input_static/'+area+'/'; DO include trailing slash.
watermask_in_file='watermask.dat'; input file name.

masked_swe_out_dir=snodis_root+'postprocess/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
masked_swe_out_file='swe.dat'; input file name.

distributed_residual_swe_out_dir=snodis_root+'postprocess/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
distributed_residual_swe_out_file='sweres.dat'; input file name.

blend_swe_out_dir=snodis_root+'postprocess/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
blend_swe_out_file='swe2.dat'; input file name.

first_year_cdec=1997; snow sensor SWE starts from 1-Jan-1997.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running postprocess...'

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

num_snodis_step=julday(last_month,last_day,year)-julday(first_month,first_day,year)+1; note this is specifically for daily outputted data.
offset_start_cdec=julday(first_month,first_day,year)-julday(1,1,first_year_cdec); number of layers to skip between 1-Jan-1997 and first model day; note this is specifically for daily CDEC SWE data which is stored in a single file.

; open data cube to read SNODIS swe.
openr,1,snodis_swe_in_dir+snodis_swe_in_file
snodis_swe_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

; open data cube to read CDEC swe.
openr,2,cdec_swe_in_dir+cdec_swe_in_file
cdec_swe_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

; open data cube to read DEM.
openr,3,dem_in_dir+dem_in_file
dem_cube=assoc(3,fltarr(ncols_snodis,nrows_snodis))

; read watermask.
watermask_grid=fltarr(ncols_snodis,nrows_snodis)
if file_test(watermask_in_dir+watermask_in_file) then begin
openr,4,watermask_in_dir+watermask_in_file
readu,4,watermask_grid
close,4
endif

; open data cube to read weight.
openr,5,temp_dir+'weight.dat'
weight_cube=assoc(5,fltarr(ncols_snodis,nrows_snodis))

; read in indices of valid snow sensor pixels.
spawn,'wc '+temp_dir+'snowsensor_pixel.txt',spawn_rc
num_site=spawn_rc(0)
index=fltarr(num_site)
openr,6,temp_dir+'snowsensor_pixel.txt'
readf,6,index
close,6

; randomly select a given percent of sites to retain for blending.
percent_to_retain=100
randnum=randomn(seed,num_site)
randidx=sort(randnum)
num_site_to_retain=round(percent_to_retain/100.0*num_site)
index_to_retain=index(randidx(0:num_site_to_retain-1))

; open data cube to write masked SNODIS swe.
if ~file_test(masked_swe_out_dir,/directory) then spawn,'mkdir -p '+masked_swe_out_dir
openw,7,masked_swe_out_dir+masked_swe_out_file
masked_swe_cube=assoc(7,fltarr(ncols_snodis,nrows_snodis))

; open data cube to write distributed residual swe.
if ~file_test(distributed_residual_swe_out_dir,/directory) then spawn,'mkdir -p '+distributed_residual_swe_out_dir
openw,8,distributed_residual_swe_out_dir+distributed_residual_swe_out_file
distributed_residual_swe_cube=assoc(8,fltarr(ncols_snodis,nrows_snodis))

; open data cube to write blended swe.
if ~file_test(blend_swe_out_dir,/directory) then spawn,'mkdir -p '+blend_swe_out_dir
openw,9,blend_swe_out_dir+blend_swe_out_file
blend_swe_cube=assoc(9,fltarr(ncols_snodis,nrows_snodis))

dem_grid=dem_cube[0]

for i=0,num_snodis_step-1 do begin; main loop.
print,string(i+1,num_snodis_step,format='("[SNODIS info] step ",I0," of ",I0," in postprocess...")')

snodis_swe_grid=snodis_swe_cube[i]; note SNODIS SWE has no missing values (filled with zeros over oceans).
tmp_index=where(snodis_swe_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then snodis_swe_grid(tmp_index)=!values.f_nan

tmp_index=where(watermask_grid eq 1.0,tmp_cnt)
if tmp_cnt ne 0 then snodis_swe_grid(tmp_index)=!values.f_nan; apply watermask for product.

cdec_swe_grid=cdec_swe_cube[i+offset_start_cdec]
tmp_index=where(cdec_swe_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then cdec_swe_grid(tmp_index)=!values.f_nan

cdec_swe_grid2=fltarr(ncols_snodis,nrows_snodis)*!values.f_nan
cdec_swe_grid2(index_to_retain)=cdec_swe_grid(index_to_retain)
cdec_swe_grid=cdec_swe_grid2

residual_swe_grid=snodis_swe_grid-cdec_swe_grid
tmp_index=where(finite(residual_swe_grid),num_site_this_step); get # of valid snow sensor pixels (out of pre-defined locations; new locations will be ignored) at this time step (could be zero).

if num_site_this_step ge 1 then begin
   tmp_grid=fltarr(ncols_snodis,nrows_snodis)
   tmp2_grid=fltarr(ncols_snodis,nrows_snodis)
   for kk=0,num_site-1 do begin
   if finite(residual_swe_grid(index(kk))) then begin
   tmp_grid=tmp_grid+residual_swe_grid(index(kk))*weight_cube(kk)
   tmp2_grid=tmp2_grid+weight_cube(kk)
   endif
   endfor
   distributed_residual_swe_grid=tmp_grid/tmp2_grid
   distributed_residual_swe_grid(index)=residual_swe_grid(index); at snow sensor sites, the two should equate.
endif else begin
   distributed_residual_swe_grid=replicate(0.0,ncols_snodis,nrows_snodis)
endelse
blend_swe_grid=fltarr(ncols_snodis,nrows_snodis)
blend_swe_grid=snodis_swe_grid-distributed_residual_swe_grid; apply residual correction for product.
tmp_index=where(blend_swe_grid lt 0.0,tmp_cnt)
if tmp_cnt ne 0 then blend_swe_grid(tmp_index)=0.0; SWE cannot physically be negative.
tmp_index=where(snodis_swe_grid eq 0.0,tmp_cnt)
if tmp_cnt ne 0 then blend_swe_grid(tmp_index)=0.0; let SWE be zero where it was zero. Note: this could result in blended SWE not equal to snow sensor SWE.

;---------------------------------------------------------------------------------
; output to files.
;---------------------------------------------------------------------------------
tmp_index=where(~finite(snodis_swe_grid),tmp_cnt)
if tmp_cnt ne 0 then snodis_swe_grid(tmp_index)=undefo; replace NaN's with undefo for file output.
masked_swe_cube[i]=snodis_swe_grid

tmp_index=where(~finite(distributed_residual_swe_grid),tmp_cnt)
if tmp_cnt ne 0 then distributed_residual_swe_grid(tmp_index)=undefo; replace NaN's with undefo for file output.
distributed_residual_swe_cube[i]=distributed_residual_swe_grid

tmp_index=where(~finite(blend_swe_grid),tmp_cnt)
if tmp_cnt ne 0 then blend_swe_grid(tmp_index)=undefo; replace NaN's with undefo for file output.
blend_swe_cube[i]=blend_swe_grid

endfor; end main loop.

close,1,2,3,4,5,7,8,9

;---------------------------------------------------------------------------------
; produce .ctl files for GrADS.
;---------------------------------------------------------------------------------
spawn,snodis_root+'postprocess/'+area+'/'+'mkctl.sh '+strcompress(year,/remove_all)

;
; end loop over years; comment out this block if running for a single year.
;
;endfor; end loop over years.

print,'[SNODIS info] ended running postprocess.'
end
