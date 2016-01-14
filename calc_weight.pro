;---------------------------------------------------------------------------------
; $Id: calc_weight.pro,v 1.5 2012/03/12 20:14:59 bguan Exp $
; Obtain indices of valid snow sensor pixels, and calculate weights for distributing residual SWE.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_weight

common param

cdec_swe_in_dir='/home/bguan/DATA/CDEC_SnowSensors/SWE_Daily0000PT/'; DO include trailing slash.
cdec_swe_in_file='SWE_Daily0000PT_SNODISGridded.dat'; input file name.

lon_out_dir=snodis_root+'postprocess/'+area+'/'; DO include trailing slash.
lon_out_file='lon.dat'; input file name.

lat_out_dir=snodis_root+'postprocess/'+area+'/'; DO include trailing slash.
lat_out_file='lat.dat'; input file name.

first_year_cdec=1997; snow sensor SWE starts from 1-Jan-1997.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_weight...'

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

; open data cube to read CDEC swe.
openr,1,cdec_swe_in_dir+cdec_swe_in_file
cdec_swe_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

; open data cube to write weights.
openw,2,temp_dir+'weight.dat'
weight_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

; define Lon/Lat grid.
lon_grid=fltarr(ncols_snodis,nrows_snodis)
for jj=0,nrows_snodis-1 do begin
lon_grid(*,jj)=dem_lon_small+findgen(ncols_snodis)*dem_pixelsize
endfor
openw,11,lon_out_dir+lon_out_file
writeu,11,lon_grid
close,11
dem_lat_small=dem_lat_large-(nrows_snodis-1)*dem_pixelsize
lat_grid=fltarr(ncols_snodis,nrows_snodis)
for ii=0,ncols_snodis-1 do begin
lat_grid(ii,*)=dem_lat_small+findgen(nrows_snodis)*dem_pixelsize
endfor
openw,12,lat_out_dir+lat_out_file
writeu,12,lat_grid
close,12

cdec_swe_grid=cdec_swe_cube[julday(8,22,2002)-julday(1,1,first_year_cdec)]; on 22-Aug-2002 all snow sensor pixels are valid.
tmp_index=where(cdec_swe_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then cdec_swe_grid(tmp_index)=!values.f_nan

index=where(finite(cdec_swe_grid),num_sites); loop over snow sensor sites to save time (instead of over all SNODIS pixels).
print,string(num_sites,format='("[SNODIS info]: ",I0," valid snow sensor pixels found.")')
openw,13,temp_dir+'snowsensor_pixel.txt'
printf,13,index,format='(I0)'
close,13

tmp_grid=fltarr(ncols_snodis,nrows_snodis)
tmp2_grid=fltarr(ncols_snodis,nrows_snodis)
for kk=0,num_sites-1 do begin
lon_here=lon_grid(index(kk))
lat_here=lat_grid(index(kk))
calc_dist,lon_here,lat_here,lon_grid,lat_grid,distance_grid
tmp_index=where(distance_grid eq 0.0,tmp_cnt)
if tmp_cnt ne 0 then distance_grid(tmp_index)=1e-5; zero distance replaced with a small value to prevent divide-by-zero error in next step.
weight_cube(kk)=1/(distance_grid^2)
endfor

close,1,2

print,'[SNODIS info] ended running calc_weight.'
end
