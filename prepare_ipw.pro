;---------------------------------------------------------------------------------
; $Id: prepare_ipw.pro,v 1.9 2012/03/12 20:14:59 bguan Exp $
; Prepare time-independent IPW images.
;
; Note: Input DEM has missing values over oceans, which will be replaced by zeros in this program. Missing values over land have been filled.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro prepare_ipw

common param

nbits=16

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running prepare_ipw...'

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

; read in DEM.
dem=fltarr(ncols_snodis,nrows_snodis)
openr,1,snodis_root+'input_static/'+area+'/dem.dat'
readu,1,dem
close,1
tmp_index=where(dem eq undefi,tmp_cnt)
if tmp_cnt ne 0 then dem(tmp_index)=0.0; replace undef values over oceans with zeros; those over land have been filled.

; write to a text file.
openw,2,temp_dir+'dem.txt'
for jj=0,nrows_snodis-1 do begin
   for ii=0,ncols_snodis-2 do begin; -2 because the last column is written separately.
      printf,2,format='(F9.2,TR1,$)',dem[ii,jj]
   endfor
   printf,2,format='(F9.2)',dem[ii,jj]
endfor
close,2

; convert text file to IPW image.
shell_comm=string(nrows_snodis,ncols_snodis,nbits,temp_dir+'dem.txt',temp_dir+'dem.ipw',format='("text2ipw -l ",I0," -s ",I0," -n ",I0," ",A," > ",A)')
print,shell_comm
spawn,shell_comm 

; flip image (so that line 0 is northernmost as required by IPW programs).
shell_comm='flip -l '+temp_dir+'dem.ipw'+' > '+temp_dir+'dem.ipw.flipped'
print,shell_comm
spawn,shell_comm 

; add geo header.
shell_comm=string(dem_lat_large,dem_lon_small,-dem_pixelsize,dem_pixelsize,temp_dir+'dem.ipw.flipped',temp_dir+'dem.ipw.flipped.geo',format='("mkgeoh -c geo -u degrees -o ",F0,",",F0," -d ",F0,",",F0," ",A," > ",A)')
print,shell_comm
spawn,shell_comm

; prepare slope and aspect (2-band image) from DEM.
shell_comm='ggradient '+temp_dir+'dem.ipw.flipped.geo'+' > '+temp_dir+'gradient.ipw.flipped.geo'
print,shell_comm
spawn,shell_comm 

; prepare sky view and terrain configuration (2-band image) from DEM; takes an hour or so to finish.
shell_comm='gviewf '+temp_dir+'dem.ipw.flipped.geo'+' > '+temp_dir+'viewf.ipw.flipped.geo'
print,shell_comm
spawn,shell_comm 

print,'[SNODIS info] ended running prepare_ipw.'
end
