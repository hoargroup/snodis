;---------------------------------------------------------------------------------
; $Id: calc_fsca_cummelt.pro,v 1.15 2012/10/29 23:16:44 bguan Exp $
; Calculate interpolated FSCA, and cummulative (actual; as opposed to potential) snow melt.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_fsca_cummelt,fsca_doy

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_fsca_cummelt...'

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

num_snodis_step=(julday(last_month,last_day,year)-julday(first_month,first_day,year)+1)*24/time_step

; read back from data cubes.
openr,1,in_dir+'cumpotmelt.dat'
cumpotmelt_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis)); cummulative potential snow melt [m].
openr,2,temp_dir+'fsca_interp_start.dat'
fsca_interp_start=assoc(2,fltarr(ncols_snodis,nrows_snodis))
openr,3,temp_dir+'fsca_interp_end.dat'
fsca_interp_end=assoc(3,fltarr(ncols_snodis,nrows_snodis))
openr,4,temp_dir+'cumpotmelt_interp_start.dat'
cumpotmelt_interp_start=assoc(4,fltarr(ncols_snodis,nrows_snodis))
openr,5,temp_dir+'cumpotmelt_interp_end.dat'
cumpotmelt_interp_end=assoc(5,fltarr(ncols_snodis,nrows_snodis))

; open write-to data cubes.
openw,6,out_dir+'fsca.dat'
fsca_cube=assoc(6,fltarr(ncols_snodis,nrows_snodis)); calculated fsca [0--1 non-dimensional].
openw,7,out_dir+'cummelt.dat'
cummelt_cube=assoc(7,fltarr(ncols_snodis,nrows_snodis)); cummulative (actual) snow melt [m].

; declare miscellaneous grids for intermediate values.
melt_grid=fltarr(ncols_snodis,nrows_snodis); [m].
cummelt_grid=fltarr(ncols_snodis,nrows_snodis); [m].
potmelt_grid=fltarr(ncols_snodis,nrows_snodis); [m]. 
cumpotmelt_grid=fltarr(ncols_snodis,nrows_snodis); [m].
fsca_grid=fltarr(ncols_snodis, nrows_snodis); [0--1 non-dimensional]. 

for i=0,num_snodis_step-1 do begin

   print,string(i+1,num_snodis_step,format='("[SNODIS info] step ",I0," of ",I0," in calc_fsca_cummelt...")')

   curr_doy=julday(first_month,first_day,year)-julday(1,1,year,0)+double(i)*time_step/24.0; current decimal doy.

   cumpotmelt_grid=cumpotmelt_cube[i]
   tmp_index=where(cumpotmelt_grid eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then cumpotmelt_grid(tmp_index)=!values.f_nan

   if i eq 0 then begin
      potmelt_grid=cumpotmelt_grid
   endif else begin
      cumpotmelt_prior_grid=cumpotmelt_cube[i-1]
      tmp_index=where(cumpotmelt_prior_grid eq undefi,tmp_cnt)
      if tmp_cnt ne 0 then cumpotmelt_prior_grid(tmp_index)=!values.f_nan
      potmelt_grid=cumpotmelt_grid-cumpotmelt_prior_grid
   endelse

   temp=where(curr_doy gt fsca_doy,count); temp gives the index of fsca_doy where curr_doy>fsca_doy.

   case count of
      0:fsca_grid=fsca_interp_start[0]
      n_elements(fsca_doy):fsca_grid=fsca_interp_end[n_elements(fsca_doy)-2]
      else:begin
         interval=count-1
         denominator=cumpotmelt_interp_end[interval]-cumpotmelt_interp_start[interval]
         index=where(denominator eq 0,count,complement=cindex); check for possible divide-by-zero problem during times of no melt.
         if count eq 0 then begin; no divide-by-zero problem; interpolate as usual. 
            fsca_grid=fsca_interp_start[interval]+(cumpotmelt_grid-cumpotmelt_interp_start[interval])*(fsca_interp_end[interval]-fsca_interp_start[interval])/denominator
         endif else begin; divide-by-zero problem; interpolate only where denominator not equal to 0.
            tmp_fsca_interp_start=fsca_interp_start[interval]
            tmp_fsca_interp_end=fsca_interp_end[interval]
            tmp_cumpotmelt_interp_start=cumpotmelt_interp_start[interval]
            tmp_cumpotmelt_interp_end=cumpotmelt_interp_end[interval]
            fsca_grid[index]=tmp_fsca_interp_start[index]; don't interpolate where no potential melt occurs; just copy the fsca at the beginning of the interval.
            fsca_grid[cindex]=tmp_fsca_interp_start[cindex]+(cumpotmelt_grid[cindex]-tmp_cumpotmelt_interp_start[cindex])*(tmp_fsca_interp_end[cindex]-tmp_fsca_interp_start[cindex])/$
            (tmp_cumpotmelt_interp_end[cindex]-tmp_cumpotmelt_interp_start[cindex])
         endelse
         fsca0=fsca_interp_start[interval]
         tmp_index=where(fsca_grid gt fsca0,tmp_cnt)
         if tmp_cnt ne 0 then fsca_grid[tmp_index]=fsca0[tmp_index]; fsca cannot increase within an interpolation interval.
      end
   endcase
   ; Note: above, missing values in cumpotmelt_interp_start and cumpotmelt_interp_end not replaced by NaN, but effectively masked out by cumpotmelt_grid.

   tmp_index=where(fsca_grid lt 0.0,tmp_cnt)
   if tmp_cnt ne 0 then fsca_grid[tmp_index]=0.0
   tmp_index=where(fsca_grid gt 1.0,tmp_cnt)
   if tmp_cnt ne 0 then fsca_grid[tmp_index]=1.0

   melt_grid=fsca_grid*potmelt_grid; [m]. 
   cummelt_grid+=melt_grid; [m].
   tmp_index=where(~finite(cummelt_grid),tmp_cnt)
   if tmp_cnt ne 0 then cummelt_grid(tmp_index)=undefo; replace NaN's with undefo for file output.
   cummelt_cube[i]=cummelt_grid; [m]. 
   tmp_index=where(~finite(fsca_grid),tmp_cnt)
   if tmp_cnt ne 0 then fsca_grid(tmp_index)=undefo; replace NaN's with undefo for file output.
   fsca_cube[i]=fsca_grid

endfor

close,1,2,3,4,5,6,7

output,'fsca'

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+in_dir+'cumpotmelt.dat '+in_dir+'fsca.dat'

print,'[SNODIS info] ended running calc_fsca_cummelt.'
end
