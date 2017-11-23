;---------------------------------------------------------------------------------
; $Id: run_ipw.pro,v 1.16 2012/10/29 23:17:12 bguan Exp $
; Run IPW programs.
;
; Note: Undef in input albedos and GOES solar radiation replaced by zeros in this program.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro run_ipw,albedo_scheme

common param

min_wavelength=0.2; minimum wavelength for IPW elevrad [micron].
max_wavelength=3.0; maximum wavelength for IPW elevrad [micron].
nbits=16

potalbedo_in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
potalbedo_in_file='potalbedo.dat'; output file name.

mixalbedo_in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
mixalbedo_in_file='mixalbedo.dat'; output file name.

goes_in_dir=snodis_root+'input_meto/'+area+'/'+strcompress(year,/remove_all)+'/'; DO include trailing slash.
goes_in_file='goes.dat'; input file name.

toporad_out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
toporad_out_file='toporad.dat'; output file name.

topogoes_out_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
topogoes_out_file='topogoes.dat'; output file name.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running run_ipw...'

temp_dir=snodis_root+'temp/'+area+'/'
if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

iregrid_multiple=ncols_snodis/ncols_nldas
jregrid_multiple=nrows_snodis/nrows_nldas

num_snodis_step=(julday(last_month,last_day,year)-julday(first_month,first_day,year)+1)*24/time_step

; open potalbedo for illumination angle correction if using BATS scheme.
openu,1,potalbedo_in_dir+potalbedo_in_file
potalbedo_cube=assoc(1,fltarr(ncols_snodis,nrows_snodis))

; open mixalbedo for read.
openr,2,mixalbedo_in_dir+mixalbedo_in_file
mixalbedo_cube=assoc(2,fltarr(ncols_snodis,nrows_snodis))

; open data cube to store toporad solar radiation.
openw,4,toporad_out_dir+toporad_out_file
toporad_cube=assoc(4,fltarr(ncols_snodis,nrows_snodis))

; open GOES.
openr,21,goes_in_dir+goes_in_file
goes_cube=assoc(21,fltarr(ncols_nldas,nrows_nldas)); note NLDAS dimensions.

; open data cube to write downscaled solar radiation.
openw,22,topogoes_out_dir+topogoes_out_file
topogoes_cube=assoc(22,fltarr(ncols_snodis,nrows_snodis)); note SNODIS dimensions.

; declare miscellaneous arrays.
f_BATS=fltarr(ncols_snodis,nrows_snodis); solar position-dependent f array (Dickinson et al. 1993).
toporad=fltarr(ncols_snodis,nrows_snodis); toporad solar radiation.
topogoes_grid=fltarr(ncols_snodis,nrows_snodis); downscaled GOES.
cosill=fltarr(ncols_snodis,nrows_snodis); cosine of solar illumination angle.

; declare constants.
b_BATS=2.0; b-value in BATS model (Dickinson et al., 1993).

first_julday=julday(first_month,first_day,year,0); julian day (NOT doy) of 0000 hour of first_month first_day.

offset_start=(julday(first_month,first_day,year,0)-julday(1,1,year,0))*24.0/time_step; number of layers to skip between 00:00 Jan-01 and first model step.

for i=0,num_snodis_step-1 do begin; loop over time steps of model.

print,string(i+1,num_snodis_step,format='("[SNODIS info] step ",I0," of ",I0," in run_ipw...")')

; get exoatmospheric solar radiation (only a function of time).
curr_julday=first_julday+double(i)*time_step/24.0; decimal julian day of this time step.
caldat,curr_julday,curr_month,curr_day,curr_year,curr_hour; get current month, day, year, hour.
opt1=string(min_wavelength,max_wavelength,format='("-w ",F0.2,",",F0.2)') 
opt2=string(curr_year,curr_month,curr_day,format='("-d ",I0,",",I0,",",I0)')
shell_comm=['solar',opt1,opt2]
;print,shell_comm
spawn,shell_comm,std_out,/NOSHELL
exoatmorad=float(std_out); convert string to number.

curr_potalbedo=potalbedo_cube[i]; note that potalbedo now starts from 1st MODEL step. 
tmp_index=where(curr_potalbedo eq undefi,tmp_cnt)
if tmp_cnt ne 0 then curr_potalbedo(tmp_index)=0.0; replace undef values over oceans with zeros.

; get solar zenith angle cosine and solar azimuth angle (2-band image). 
shell_comm=string(dem_lat_large,dem_lon_small,-dem_pixelsize,dem_pixelsize,temp_dir+'dem.ipw.flipped',curr_year,curr_month,curr_day,curr_hour,temp_dir+'sunlight.ipw.flipped.geo',format='("mkgeoh -c geo -u degrees -o ",F0,",",F0," -d ",F0,",",F0," -f ",A," | gsunlight -t ",I0,",",I0,",",I0,",",I0," > ",A)')
;print,shell_comm
spawn,shell_comm

; extract solar zenith angle cosine from the 2-band image, and convert to binary file.
shell_comm1='demux -b 0 '+temp_dir+'sunlight.ipw.flipped.geo'+' > '+temp_dir+'coszenith.ipw.flipped.geo'
shell_comm2='ipw2bin '+temp_dir+'coszenith.ipw.flipped.geo'+' > '+temp_dir+'coszenith.dat.flipped'
;print,shell_comm1
spawn,shell_comm1
;print,shell_comm2
spawn,shell_comm2

; read in coszenith (in flipped order since it's output from gsunlight).
coszenith_flipped=fltarr(ncols_snodis,nrows_snodis)
openr,5,temp_dir+'coszenith.dat.flipped'
readu,5,coszenith_flipped; line 0 is northernmost.
close,5

if max(coszenith_flipped) le 0.0 then begin; if Sun is at or below the horizon for the entire domain.
   ; Sun down, so no correction for potalbedo; this doesn't matter because no radiation occurs at these times.
   toporad_cube[i]=replicate(0.0,ncols_snodis,nrows_snodis); assume zero downscaled solar radiation; toporad won't run for these times.
endif else begin; run IPW programs if Sun is above the horizon for at least part of the domain.
   curr_mixalbedo=mixalbedo_cube[i]
   tmp_index=where(curr_mixalbedo eq undefi,tmp_cnt)
   if tmp_cnt ne 0 then curr_mixalbedo(tmp_index)=0.0; replace undef values over oceans with zeros.
 
   ; write the surface albedo to a text file and convert it to an IPW file.
   openw,6,temp_dir+'mixalbedo.txt'
   for jj=0,nrows_snodis-1 do begin
      for ii=0,ncols_snodis-2 do begin; -2 because the last column is written separately.
         printf,6,format='(F6.4,TR1,$)',curr_mixalbedo[ii,jj]
      endfor
      printf,6,format='(F6.4)',curr_mixalbedo[ii,jj]
   endfor
   close,6
   shell_comm='text2ipw -l '+strcompress(nrows_snodis,/remove_all)+' -s '+strcompress(ncols_snodis,/remove_all)+' -n '+strcompress(nbits,/remove_all)+' '+temp_dir+'mixalbedo.txt'+' > '+temp_dir+'mixalbedo.ipw'
;   print,shell_comm
   spawn,shell_comm

   ; flip image (so that line 0 is northernmost as required by IPW programs).
   shell_comm='flip -l '+temp_dir+'mixalbedo.ipw'+' > '+temp_dir+'mixalbedo.ipw.flipped'
;   print,shell_comm
   spawn,shell_comm

   ; create constant optical depth field for elevrad.
   openw,7,temp_dir+'optdepth.txt'
   for jj=0,nrows_snodis-1 do begin
      for ii=0,ncols_snodis-2 do begin; -2 because the last column is written separately.
         printf,7,format='(F6.4,TR1,$)',optdepth
      endfor
      printf,7,format='(F6.4)',optdepth
   endfor
   close,7
   shell_comm='text2ipw -l '+strcompress(nrows_snodis,/remove_all)+' -s '+strcompress(ncols_snodis,/remove_all)+' -n '+strcompress(nbits,/remove_all)+' '+temp_dir+'optdepth.txt'+' > '+temp_dir+'optdepth.ipw'
;   print,shell_comm
   spawn,shell_comm
 
   ; get beam and diffuse irradiance (2-band image).
   shell_comm=string(temp_dir+'dem.ipw.flipped.geo',temp_dir+'coszenith.ipw.flipped.geo',temp_dir+'mixalbedo.ipw.flipped',temp_dir+'optdepth.ipw',refelev,omega,gfactor,exoatmorad,temp_dir+'elevrad.ipw.flipped.geo',format='("mux ",A," ",A," ",A," ",A," | gelevrad -z ",F0," -w ",F0," -g ",F0," -s ",F0," > ",A)')
;   print,shell_comm
   spawn,shell_comm

   ; get illumination angle cosine.
   shell_comm='gshade -s '+temp_dir+'sunlight.ipw.flipped.geo'+' -i '+temp_dir+'gradient.ipw.flipped.geo'+' > '+temp_dir+'shade.ipw.flipped.geo'
;   print,shell_comm
   spawn,shell_comm

   ; un-flip (so that line 0 is southernmost), convert to a binary file, read in, and store in data cube.
   shell_comm1='flip -l '+temp_dir+'shade.ipw.flipped.geo'+' > '+temp_dir+'shade.ipw.geo'
   shell_comm2='ipw2bin '+temp_dir+'shade.ipw.geo'+' > '+temp_dir+'shade.dat'
;   print,shell_comm1
   spawn,shell_comm1
;   print,shell_comm2
   spawn,shell_comm2
   openr,8,temp_dir+'shade.dat'
   readu,8,cosill
   close,8

   ; illumination angle correction if using BATS scheme (Dickinson et al., 1993).
   if albedo_scheme eq 'BATS' then begin
   f_BATS=(1.0/b_BATS)*((b_BATS+1.0)/(1+2*b_BATS*cosill)-1)
   tmp_index=where(cosill gt 0.5,tmp_cnt)
   if tmp_cnt ne 0 then f_BATS[tmp_index]=0.0; Eqn. 6 in Dickinson et al. (1993).
   potalbedo_cube[i]=curr_potalbedo*(1-0.4*f_BATS)+0.4*f_BATS
   endif

   ; run gtoporad.
   shell_comm=string(temp_dir+'coszenith.ipw.flipped.geo',temp_dir+'elevrad.ipw.flipped.geo',temp_dir+'shade.ipw.flipped.geo',temp_dir+'viewf.ipw.flipped.geo',temp_dir+'mixalbedo.ipw.flipped',temp_dir+'mixalbedo.ipw.flipped',temp_dir+'toporad.ipw.flipped.geo',format='("mux ",A," ",A," ",A," ",A," ",A," ",A," | gtoporad > ",A)')
;   print,shell_comm
   spawn,shell_comm

   ; un-flip (so that line 0 is southernmost), convert to a binary file, read in, and store in data cube.
   shell_comm1='flip -l '+temp_dir+'toporad.ipw.flipped.geo'+' > '+temp_dir+'toporad.ipw.geo'
   shell_comm2='ipw2bin '+temp_dir+'toporad.ipw.geo'+' > '+temp_dir+'toporad.dat'
;   print,shell_comm1
   spawn,shell_comm1
;   print,shell_comm2
   spawn,shell_comm2
   openr,9,temp_dir+'toporad.dat'
   readu,9,toporad
   close,9
   toporad_cube[i]=toporad
endelse

;---------------------------------------------------------------------------------
; done with IPW programs.
;---------------------------------------------------------------------------------

; downscale gridded GOES using toporad.
if max(coszenith_flipped) le 0.0 then begin
   topogoes_grid=replicate(0.0,ncols_snodis,nrows_snodis)
endif else begin
goes_grid=goes_cube(i+offset_start)
tmp_index=where(goes_grid eq undefi,tmp_cnt)
if tmp_cnt ne 0 then goes_grid(tmp_index)=0.0; replace undef values over oceans with zeros.
toporad_istart=0
toporad_jstart=0
for nldasj=0,nrows_nldas-1 do begin
    for nldasi=0,ncols_nldas-1 do begin
    goes_point=goes_grid(nldasi,nldasj)
    toporad_i=toporad_istart+nldasi*iregrid_multiple
    toporad_j=toporad_jstart+nldasj*jregrid_multiple
    toporad_subgrid=toporad(toporad_i:toporad_i+iregrid_multiple-1,toporad_j:toporad_j+jregrid_multiple-1)
    toporad_subgrid_mean=mean(toporad_subgrid)
    if toporad_subgrid_mean ne 0.0 then begin; denominator is not zero.
       topogoes_subgrid=toporad_subgrid/toporad_subgrid_mean*goes_point
    endif else begin; denominator is zero (this happens only when all pixels in toporad_subgrid are zeros since radiation cannot be negative; when this happens, set all pixels in topogoes_subgrid to zero).
       topogoes_subgrid=toporad_subgrid
    endelse
    topogoes_grid(toporad_i:toporad_i+iregrid_multiple-1,toporad_j:toporad_j+jregrid_multiple-1)=topogoes_subgrid
    endfor
endfor
endelse
topogoes_cube[i]=topogoes_grid

if check_math() ne 0 then begin
print,'[SNODIS error] math error occurred in run_ipw; program stopped.'
stop
endif

endfor; end main loop.

close,1,2,4,21,22

; remove intermediate files to conserve disk space.
;spawn,'rm -f '+mixalbedo_in_dir+'mixalbedo.dat '+toporad_out_dir+'toporad.dat'

print,'[SNODIS info] ended running run_ipw.'
end

; References
; 
; Dickinson, R.E., A. Henderson-Sellers and P.J. Kennedy (1993). Biosphere-Atmosphere Transfer
; Scheme (BATS) Version 1e as coupled to the NCAR Community Climate Model. NCAR Technical Note 
; NCAR/TN-387+STR, National Center for Atmospheric Research, Boulder, CO.
