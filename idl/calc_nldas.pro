;---------------------------------------------------------------------------------
; $Id: calc_nldas.pro,v 1.19 2012/10/29 23:17:12 bguan Exp $
; Downscale NLDAS data for input to SNODIS.
;
; Note: Input DEMs have missing values over oceans, which will NOT be filled in this program. (Missing values over land have been filled.)
;       Output downscaled data have missing values over oceans.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_nldas,varname

common param

in_dir=snodis_root+'input_meto/'+area+'/'+strcompress(year,/remove_all)+'/'; DO include trailing slash.
in_file=varname+'.dat'; input file name.

out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_file=varname+'.dat'; output file name.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running calc_nldas...'

num_forcing_step=(julday(nldas_last_month,nldas_last_day,year)-julday(1,1,year)+1)*24.0/time_step; MUST start from Jan-01.

ratio_cols=ncols_snodis/ncols_nldas
ratio_rows=nrows_snodis/nrows_nldas

; read in forest density to adjust windspeed based on forest fraction
; read forden (cannot have missing values).
; forden is used (1) in prepare_fsca_fscamask.pro to apply vgf-correction, (2) in calc_turblong.pro, and (3) calc_energy.pro to scale incoming solar radiation with forsol_coeff (4) here to reduce windspeed according to forest fraction
forden_in_dir=snodis_root+'input_static/'+area+'/'; DO include trailing slash.
forden=fltarr(ncols_snodis,nrows_snodis); [0--1 non-dimensional]
;input file name set in main
if file_test(forden_in_dir+forden_in_file) then begin
openr,1,forden_in_dir+forden_in_file
readu,1,forden
close,1
endif

; read in DEM on NLDAS grid (1/8 deg x 1/8 deg).
dem_nldas=fltarr(ncols_nldas,nrows_nldas)
openr,1,snodis_root+'input_static/'+area+'/dem4nldas.dat'
readu,1,dem_nldas
close,1
tmp_index=where(dem_nldas eq undefi,tmp_cnt)
if tmp_cnt ne 0 then dem_nldas(tmp_index)=!values.f_nan
dem_nldas_mask=replicate(1.0,ncols_nldas,nrows_nldas)
tmp_index=where(~finite(dem_nldas),tmp_cnt)
if tmp_cnt ne 0 then dem_nldas_mask(tmp_index)=0.0; set mask to zero over oceans.

; read in DEM on SNODIS grid.
dem_snodis=fltarr(ncols_snodis,nrows_snodis)
openr,2,snodis_root+'input_static/'+area+'/dem.dat'
readu,2,dem_snodis
close,2
tmp_index=where(dem_snodis eq undefi,tmp_cnt)
if tmp_cnt ne 0 then dem_snodis(tmp_index)=!values.f_nan

; open input NLDAS.
openr,3,in_dir+in_file
var_nldas_cube=assoc(3,fltarr(ncols_nldas,nrows_nldas))

; calculate lapse rate based on time mean (i.e., lapse rate is fixed for all time steps).
;var_nldas_mean=fltarr(ncols_nldas,nrows_nldas)
;for i=0,num_forcing_step-1 do begin
;var_nldas=var_nldas_cube(i); read in NLDAS.
;tmp_index=where(var_nldas eq undefi,tmp_cnt)
;if tmp_cnt ne 0 then var_nldas(tmp_index)=!values.f_nan
;var_nldas_mean+=var_nldas
;endfor
;var_nldas_mean/=num_forcing_step
;var_nldas_mean_mask=replicate(1.0,ncols_nldas,nrows_nldas)
;tmp_index=where(~finite(var_nldas_mean),tmp_cnt)
;if tmp_cnt ne 0 then var_nldas_mean_mask(tmp_index)=0.0; set mask to zero over oceans.
;mask=dem_nldas_mask*var_nldas_mean_mask; zeros where either DEM or variable has missing values; ones elsewhere.
;nonmissing_index=where(mask eq 1)
;if(max(var_nldas,/nan) ne min(var_nldas,/nan)) then begin; non-constant field.
;s=regress(reform(dem_nldas(nonmissing_index),n_elements(dem_nldas(nonmissing_index))),reform(var_nldas_mean(nonmissing_index),n_elements(var_nldas(nonmissing_index))),correlation=r)
;slope=s(0); needed to convert to scalar, so that [1,2,3]*a=[a,2*a,3*a].
;corr=r
;endif else begin; constant field.
;slope=0.0
;corr=1.0
;endelse
;print,'[SNODIS info] r = ',corr

; open (for write) downscaled NLDAS.
if ~file_test(out_dir,/directory) then spawn,'mkdir -p '+out_dir
openw,4,out_dir+out_file
var_snodis_cube=assoc(4,fltarr(ncols_snodis,nrows_snodis))

for i=0,num_forcing_step-1 do begin
print,string(i+1,num_forcing_step,varname,format='("[SNODIS info] step ",I0," of ",I0," in calc_nldas,",A,"...")')
var_nldas=var_nldas_cube(i); read in NLDAS.
tmp_index=where(var_nldas eq undefi,tmp_cnt)
if tmp_cnt ne 0 then var_nldas(tmp_index)=!values.f_nan
var_nldas_mask=replicate(1.0,ncols_nldas,nrows_nldas)
tmp_index=where(~finite(var_nldas),tmp_cnt)
if tmp_cnt ne 0 then var_nldas_mask(tmp_index)=0.0; set mask to zero over oceans.
mask=dem_nldas_mask*var_nldas_mask; zeros where either DEM or variable has missing values; ones elsewhere.
nonmissing_index=where(mask eq 1)
if(max(var_nldas,/nan) ne min(var_nldas,/nan)) then begin; non-constant field.
s=regress(reform(dem_nldas(nonmissing_index),n_elements(dem_nldas(nonmissing_index))),reform(var_nldas(nonmissing_index),n_elements(var_nldas(nonmissing_index))),correlation=r)
slope=s(0); needed to convert to scalar, so that [1,2,3]*a=[a,2*a,3*a].
corr=r
endif else begin; constant field.
slope=0.0
corr=1.0
endelse
;print,'[SNODIS info] r = ',corr
residual_nldas=var_nldas-dem_nldas*slope
position_col=(findgen(ncols_snodis)-(ratio_cols/2-0.5))/ratio_cols
position_row=(findgen(nrows_snodis)-(ratio_rows/2-0.5))/ratio_rows
residual_snodis=interpolate(residual_nldas,position_col,position_row,/grid)
var_snodis=dem_snodis*slope+residual_snodis

if varname eq 'windspeed' || varname eq 'precip' then begin; these variables cannot physically be negative.
tmp_index=where(var_snodis lt 0.0,tmp_cnt)
if tmp_cnt ne 0 then var_snodis(tmp_index)=0.0
endif

if varname eq 'windspeed' then var_snodis=var_snodis*(1-0.8*forden)
;windspeed = windspeed * (1-0.8*forden) ; Tarboton et al. 1996. pg 17 corrects windspeed for forest fraction.

tmp_index=where(~finite(var_snodis),tmp_cnt)
if tmp_cnt ne 0 then var_snodis(tmp_index)=undefo; replace NaN's with undefo for file output.
var_snodis_cube(i)=var_snodis

endfor

close,3,4

print,'[SNODIS info] ended running calc_nldas.'
end
