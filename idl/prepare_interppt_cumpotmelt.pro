;---------------------------------------------------------------------------------
; $Id: prepare_interppt_cumpotmelt.pro,v 1.10 2012/10/29 23:17:12 bguan Exp $
; Prepare files containing the beginning and ending interpolation cumpotmelt
; for each model time step after taking into account cloudy pixels.
;
; Note: Input doy_interp_start.dat and doy_interp_end.dat cannot have missing values.
;       Input cumpotmelt.dat can have missing values (no need to deal with missing values since values of cumpotmelt are not used in this program).
;       Output cumpotmelt_interp_start.dat and cumpotmelt_interp_end.dat can have missing values.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro prepare_interppt_cumpotmelt,fsca_doy

common param

cumpotmelt_in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running prepare_interppt_cumpotmelt...'

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

num_fsca=n_elements(fsca_doy) 
num_interval=n_elements(fsca_doy)-1; number of interpolation intervals.

openr,1,cumpotmelt_in_dir+'cumpotmelt.dat'
cumpotmelt_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

openr,2,temp_dir+'doy_interp_start.dat'
doy_interp_start=assoc(2,fltarr(ncols_snodis,nrows_snodis))

openr,3,temp_dir+'doy_interp_end.dat'
doy_interp_end=assoc(3,fltarr(ncols_snodis,nrows_snodis))

openw,4,temp_dir+'cumpotmelt_interp_start.dat'
cumpotmelt_interp_start=assoc(4,fltarr(ncols_snodis,nrows_snodis))
cumpotmelt_interp_start[num_interval-1]=fltarr(ncols_snodis,nrows_snodis)

openw,5,temp_dir+'cumpotmelt_interp_end.dat'
cumpotmelt_interp_end=assoc(5,fltarr(ncols_snodis,nrows_snodis))
cumpotmelt_interp_end[num_interval-1]=fltarr(ncols_snodis,nrows_snodis)

doy_start=julday(first_month,first_day,year,0)-julday(1,1,year,0)+0.0; DECIMAL doy corresponding to layer 0 of cumpotmelt (i.e., if first_month=1 and first_day=1 then doy_start=0.0).

for i=0,num_fsca-1 do begin; loop over fsca images.
   print,string(i+1,num_fsca,format='("[SNODIS info] step ",I0," of ",I0," in prepare_interppt_cumpotmelt...")')

   curr_doy=fsca_doy[i]; decimal doy.
   index_cumpotmelt=(curr_doy-doy_start)*24.0/time_step; index in cumpotmelt corresponding to curr_doy.
 
   curr_cumpotmelt=cumpotmelt_cube[index_cumpotmelt]

   for j=0,num_interval-1 do begin; loop over interpolation intervals.
      tmp_cumpotmelt_interp_start=replicate(0.0,ncols_snodis,nrows_snodis)
      tmp_cumpotmelt_interp_end=replicate(0.0,ncols_snodis,nrows_snodis)  
      tmp_doy_interp_start=doy_interp_start[j]
      tmp_doy_interp_end=doy_interp_end[j]   
      tmp_index=where(tmp_doy_interp_start eq curr_doy,tmp_cnt)
      if tmp_cnt ne 0 then begin
         tmp_cumpotmelt_interp_start[tmp_index]=curr_cumpotmelt[tmp_index]
         cumpotmelt_interp_start[j]=cumpotmelt_interp_start[j]+tmp_cumpotmelt_interp_start
      endif
      tmp_index=where(tmp_doy_interp_end eq curr_doy,tmp_cnt)
      if tmp_cnt ne 0 then begin
         tmp_cumpotmelt_interp_end[tmp_index]=curr_cumpotmelt[tmp_index]
         cumpotmelt_interp_end[j]=cumpotmelt_interp_end[j]+tmp_cumpotmelt_interp_end  
      endif
   endfor

endfor

close,1,2,3,4,5

print,'[SNODIS info] ended running prepare_interppt_cumpotmelt.'
end
