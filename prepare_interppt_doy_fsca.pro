;---------------------------------------------------------------------------------
; $Id: prepare_interppt_doy_fsca.pro,v 1.15 2012/11/02 22:44:25 bguan Exp $
; Prepare files containing the beginning and ending interpolation times
; and fsca images for each model time step after taking into account cloudy pixels.
;
; Note 1: Input fsca_doy cannot have missing values.
; Note 2: Input fsca_cube cannot have missing values (missing value info derived from fscamask_cube).
; Note 3: Input fscamask_cube can have missing values. See legend below for translation in this procedure.
;         0-1 (fractional snow; >=0 & <=100 is used in the program below to identify snowy pixels which is fine) --> good (this is the only case when MODSCAG value is retained)
;         200 (missing data) --> missing
;         201 (no decision) --> missing
;         211 (night) --> missing
;         225 (land) --> force 0
;         237 (inland water) --> force 0
;         239 (ocean) --> force 0
;         250 (cloud) --> bad
;         254 (detector saturated) --> missing
;         255 (fill) --> missing
;         -9999 --> missing
;
; Copyright (C) 2011. All rights reserved.
;---------------------------------------------------------------------------------
pro prepare_interppt_doy_fsca,fsca_doy

common param

;---------------------------------------------------------------------------------
; no user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running prepare_interppt_doy_fsca...'

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

num_fsca=n_elements(fsca_doy)

openu,1,temp_dir+'fsca.dat'; open for input and output (first and last layers will be adjusted and overwritten).
fsca_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))
openr,2,temp_dir+'fscamask.dat'
fscamask_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

; adjust first fsca image by setting the value of each pixel in the first fsca image to the first cloud-free pixel for the season.
first_fsca=replicate(-10.0,ncols_snodis,nrows_snodis)
i=0
temp_fsca=fsca_cube[i]
temp_fscamask=fscamask_cube[i]
tmp_index=where(temp_fscamask eq 225 or temp_fscamask eq 237 or temp_fscamask eq 239,tmp_cnt); indices of land/inland-water/ocean pixels.
if tmp_cnt ne 0 then first_fsca[tmp_index]=0.0; force to zero.
tmp_index=where(temp_fscamask ge 0.0 and temp_fscamask le 100.0,tmp_cnt); indices of cloud-free pixels.
if tmp_cnt ne 0 then first_fsca[tmp_index]=temp_fsca[tmp_index]
index=where(first_fsca eq -10.0,count); see if any pixels still need to be filled in.
while count ne 0 do begin
  i++
  if i ge num_fsca then begin
     print,'SNODIS warning: First SCA image could not be fully populated with observed SCA values. Ones were filled.'
     first_fsca(index)=1.0
     break
  endif
  temp_fsca=fsca_cube[i]
  temp_fscamask=fscamask_cube[i]
  index2=where(temp_fscamask[index] ge 0.0 and temp_fscamask[index] le 100.0, count2) ; count cloud-free pixels in next cloud image.
  if count2 ne 0 then begin
     index3=index[index2]
     first_fsca[index3]=temp_fsca[index3]
  endif
  index=where(first_fsca eq -10.0,count); see if any days still need to be filled in.
endwhile

; adjust last snow image by setting the value of each pixel in the last fsca image to the last cloud-free pixel for the season.
last_fsca=replicate(-10.0,ncols_snodis,nrows_snodis)
i=num_fsca-1 
temp_fsca=fsca_cube[i]
temp_fscamask=fscamask_cube[i]
tmp_index=where(temp_fscamask eq 225 or temp_fscamask eq 237 or temp_fscamask eq 239,tmp_cnt); indices of land/inland-water/ocean pixels.
if tmp_cnt ne 0 then last_fsca[tmp_index]=0.0; force to zero.
tmp_index=where(temp_fscamask ge 0.0 and temp_fscamask le 100.0,tmp_cnt); indices of cloud-free pixels.
if tmp_cnt ne 0 then last_fsca[tmp_index]=temp_fsca[tmp_index]
index=where(last_fsca eq -10.0,count); see if any pixels still need to be filled in.
while count ne 0 do begin
  i--
  if i lt 0 then begin
     print,'SNODIS warning: Last SCA image could not be fully populated with observed SCA values. Zeros were filled.'
     last_fsca(index)=0.0
     break
  endif
  temp_fsca=fsca_cube[i]
  temp_fscamask=fscamask_cube[i]
  index2=where(temp_fscamask[index] ge 0.0 and temp_fscamask[index] le 100.0,count2); indices of cloud-free pixels.
  if count2 ne 0 then begin
     index3=index[index2]
     last_fsca[index3]=temp_fsca[index3]
  endif
  index=where(last_fsca eq -10.0,count); see if any days still need to be filled in.
endwhile

; Note: If the routine failed before this point, then at least one pixel is cloudy
; during all fsca acquisition times. The routine needs to be revised to accommodate
; this if this turns out to occur.

fsca_cube[0]=first_fsca
fsca_cube[num_fsca-1]=last_fsca

; create interpolation endpoints using fscamask.
num_interp_interval=num_fsca-1; number of time intervals that we're interpolating over.

openw,11,temp_dir+'doy_interp_start.dat'
openw,12,temp_dir+'doy_interp_end.dat'
doy_interp_start=assoc(11,fltarr(ncols_snodis,nrows_snodis))
doy_interp_end=assoc(12,fltarr(ncols_snodis,nrows_snodis))

openw,13,temp_dir+'fsca_interp_start.dat'
openw,14,temp_dir+'fsca_interp_end.dat'
fsca_interp_start=assoc(13,fltarr(ncols_snodis,nrows_snodis))
fsca_interp_end=assoc(14,fltarr(ncols_snodis,nrows_snodis))

for i=0,num_interp_interval-1 do begin; loop over all interpolation intervals.
   print,string(i+1,num_interp_interval,format='("[SNODIS info] step ",I0," of ",I0," in prepare_interppt_doy_fsca...")')

   if i eq 0 then begin; fill in first layer of fsca_interp_start. 
      fsca_interp_start[i]=fsca_cube[i]; fsca_cube[0] has no missing values due to filling procedures earlier.
      doy_interp_start[i]=replicate(fsca_doy[i],ncols_snodis,nrows_snodis)  
   endif else begin; fill in other layers of fsca_interp_start.
      j=i
      temp_y=fsca_cube[j]
      y=replicate(-10.0,ncols_snodis,nrows_snodis)
      t=fltarr(ncols_snodis,nrows_snodis)
      index=where(fscamask_cube[j] eq 225 or fscamask_cube[j] eq 237 or fscamask_cube[j] eq 239,count); indices of land/inland-water/ocean pixels.
      if count ne 0 then begin
         y[index]=0.0; force to zero.
         t[index]=fsca_doy[j]
      endif
      index=where(fscamask_cube[j] ge 0.0 and fscamask_cube[j] le 100.0,count); indices of cloud-free pixels.
      if count ne 0 then begin
         y[index]=temp_y[index]; fill in as many non-cloudy pixels with snow as possible.
         t[index]=fsca_doy[j] 
      endif
      index=where(y eq -10.0,count); see if any pixels still need to be filled in.
      while count ne 0 do begin
         j--; go to previous doy.
         temp_y=fsca_cube[j]
         if j eq 0 then begin
            y[index]=temp_y[index]
            t[index]=fsca_doy[j]
            break; exit the while loop gracefully (because fsca_cube[0] has no missing values due to filling procedures earlier).
         endif
         temp_fscamask=fscamask_cube[j]
         index2=where(temp_fscamask[index] ge 0.0 and temp_fscamask[index] le 100.0,count2)
         if count2 ne 0 then begin
            index3=index[index2]
            y[index3]=temp_y[index3]; fill in as many non-cloudy pixels with snow as possible.
            t[index3]=fsca_doy[j]        
         endif 
         index=where(y eq -10.0,count)
      endwhile
      fsca_interp_start[i]=y
      doy_interp_start[i]=t
   endelse
 
   if i eq num_interp_interval-1 then begin; fill in last layer of fsca_interp_end.
      fsca_interp_end[i]=fsca_cube[i+1]; fsca_cube[<end>] has no missing values due to filling procesures earlier.
      doy_interp_end[i]=replicate(fsca_doy[i+1],ncols_snodis,nrows_snodis)
   endif else begin; fill in other layers of fsca_interp_end.
      j=i
      temp_y=fsca_cube[j+1]
      y=replicate(-10.0,ncols_snodis,nrows_snodis)
      t=fltarr(ncols_snodis,nrows_snodis)
      index=where(fscamask_cube[j+1] eq 225 or fscamask_cube[j+1] eq 237 or fscamask_cube[j+1] eq 239,count); indices of land/inland-water/ocean pixels.
      if count ne 0 then begin
         y[index]=0.0; force to zero.
         t[index]=fsca_doy[j+1]
      endif
      index=where(fscamask_cube[j+1] ge 0.0 and fscamask_cube[j+1] le 100.0,count); indices of cloud-free pixels.
      if count ne 0 then begin
         y[index]=temp_y[index]
         t[index]=fsca_doy[j+1]
      endif
      index=where(y eq -10.0,count); see if any pixels still need to be filled in.
      while count ne 0 do begin
         j++; go to next doy.
         temp_y=fsca_cube[j+1]
         if j eq num_interp_interval-1 then begin
            y[index]=temp_y[index]; fill in as many non-cloudy pixels with snow as possible.
            t[index]=fsca_doy[j+1]
            break; exit the loop gracefully (because fsca_cube[<end>] has no missing values due to filling procedures earlier).
         endif
         temp_fscamask=fscamask_cube[j+1]
         index2=where(temp_fscamask[index] ge 0.0 and temp_fscamask[index] le 100.0,count2)
         if count2 ne 0 then begin
            index3=index[index2]
            y[index3]=temp_y[index3]; fill in as many non-cloudy pixels with snow as possible.
            t[index3]=fsca_doy[j+1] 
         endif
         index=where(y eq -10.0,count)
      endwhile
      fsca_interp_end[i]=y
      doy_interp_end[i]=t
   endelse
endfor

close,1,2,11,12,13,14

print,'[SNODIS info] ended running prepare_interppt_doy_fsca.'
end
