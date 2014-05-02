;---------------------------------------------------------------------------------
; $Id: calc_mixalbedo.pro,v 1.16 2012/10/29 23:17:02 bguan Exp $
; Calculate mixalbedo.
;
; Note: Input potalbedo and output mixalbedo have missing values over oceans.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_mixalbedo,fsca_doy

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
in_file='potalbedo.dat'; input file name.

out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_file='mixalbedo.dat'; output file name.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_mixalbedo...'

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

albedo_rock=0.19; albedo of rock/soil for toporad (Baldridge et al. 2009); see note 1 in main program; [non-dimensional].

num_snodis_step=(julday(last_month,last_day,year)-julday(first_month,first_day,year)+1)*24/time_step

; open data cube to read potalbedo.
openr,1,in_dir+in_file
potalbedo_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

; open data cube to write mixalbedo. 
openw,2,out_dir+out_file
mixalbedo_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

openr,11,temp_dir+'doy_interp_start.dat'
openr,12,temp_dir+'doy_interp_end.dat'
openr,13,temp_dir+'fsca_interp_start.dat'
openr,14,temp_dir+'fsca_interp_end.dat'
doy_interp_start=assoc(11,fltarr(ncols_snodis,nrows_snodis))
doy_interp_end=assoc(12,fltarr(ncols_snodis,nrows_snodis))
fsca_interp_start=assoc(13,fltarr(ncols_snodis,nrows_snodis))
fsca_interp_end=assoc(14,fltarr(ncols_snodis,nrows_snodis))

for i=0,num_snodis_step-1 do begin 
    print,string(i+1,num_snodis_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_mixalbedo...")')

    curr_doy=julday(first_month,first_day,year)-julday(1,1,year,0)+double(i)*time_step/24.0; current decimal doy.
    curr_potalbedo=potalbedo_cube[i]
    tmp_index=where(curr_potalbedo eq undefi,tmp_cnt)
    if tmp_cnt ne 0 then curr_potalbedo(tmp_index)=!values.f_nan
 
    ; determine which interpolation interval curr_doy belongs in.
    temp=where(curr_doy gt fsca_doy,count)
    case count of
       0:begin 
       fsca_interp=fsca_interp_start[0]
       end
       n_elements(fsca_doy):begin 
       fsca_interp=fsca_interp_end[n_elements(fsca_doy)-2]
       end
       else:begin
       interval=count-1; index of the interval (starts from 0).
       fsca_interp=fsca_interp_start[interval]+(curr_doy-doy_interp_start[interval])*(fsca_interp_end[interval]-fsca_interp_start[interval])/(doy_interp_end[interval]-doy_interp_start[interval])
       end 
    endcase
    fsca0=fsca_interp_start[0]
    tmp_index=where(fsca_interp gt fsca0,tmp_cnt)
    if tmp_cnt ne 0 then fsca_interp[tmp_index]=fsca0[tmp_index]; FSCA not allowed to increase.
    mixalbedo=curr_potalbedo*fsca_interp+albedo_rock*(1.0-fsca_interp)
    tmp_index=where(~finite(mixalbedo),tmp_cnt)
    if tmp_cnt ne 0 then mixalbedo(tmp_index)=undefo; replace NaN's with undefo for file output.
    mixalbedo_cube[i]=mixalbedo
endfor

close,1,2,11,12,13,14

print,'[SNODIS info] ended running calc_mixalbedo.'
end
