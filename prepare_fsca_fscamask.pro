;---------------------------------------------------------------------------------
; $Id: prepare_fsca_fscamask.pro,v 1.9 2011/10/21 20:28:53 bguan Exp $
; Read in fsca and fscamask from files and store selected images in temporary files.
; fsca is corrected for viewable gap fraction using forden in this procedure.
;
; Note 1: Input/output fsca (fscamask) cannot (can) have missing values; input forden cannot have missing values.
; Note 2: forden has value 1.0 in some places, which will be adjusted to 0.999 in this procedure to avoid divide-by-zero
;         when applying vgf correction. The vgf-corrected fsca=~Inf where forden=1 and fsca ne 0; adjusted to 1.0 to be physical.
; Note 3: forden has value 0 over the oceans as of this version.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro prepare_fsca_fscamask,fsca_doy

common param

fsca_in_dir=snodis_root+'input_fsca/'+area+'/'+strcompress(year,/remove_all)+'/'; DO include trailing slash.
fsca_in_file=strcompress(year,/remove_all)+'.dat'

fscamask_in_dir=snodis_root+'input_fscamask/'+area+'/'+strcompress(year,/remove_all)+'/'; DO include trailing slash.
fscamask_in_file=strcompress(year,/remove_all)+'.dat'

forden_in_dir=snodis_root+'input_static/'+area+'/'; DO include trailing slash.
;input file name set in main

dateselect_in_dir=snodis_root+'input_fsca/'+area+'/'+strcompress(year,/remove_all)+'/'; DO include trailing slash.
dateselect_in_file='dateselect.txt'

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running prepare_fsca_fscamask...'

;use environment variable TMPDIR to create /temp on execution node. if running on janus with array job then must change TMPDIR directory in submission script to not include [ ].
; mytemp=getenv('TMPDIR')
; temp_dir=mytemp+'/'+'temp/'+area+'/' ;DO include trailing slash.
; if ~file_test(temp_dir,/directory) then spawn,'mkdir -p '+temp_dir

;escape [ and ] in TMPDIR
;mytemp=getenv('TMPDIR') ; use next line to escape [ and ] in directory name when running job array.
;spawn,'printenv TMPDIR | sed "s/\[/\\\[/" | sed "s/\]/\\\]/"',mytemp
;temp_dir=mytemp+'/'+'temp/'+area+'/' ;DO include trailing slash.

;trying to use symbolic links to define temp_dir
;mytemp=getenv('TMPDIR')
;tempf=mytemp+'/'+'temp/'+area+'/'
;spawn,'mkdir -p '+tempf
;if ~file_test(tempf,/directory) then spawn,'mkdir -p '+tempf
;spawn, 'ln -sf '+tempf+' /local/scratch/temp_dir'
;temp_dir='/local/scratch/temp_dir/'


; get dateselect (selected calendar dates from a .txt file; date format: DDMMMYYYY).
spawn,'wc -l '+dateselect_in_dir+dateselect_in_file,rc
tmparr=strsplit(rc,' ',/extract)
num_fsca=tmparr(0)
dateselect=strarr(num_fsca); note this is a string array.
openr,31,dateselect_in_dir+dateselect_in_file
readf,31,dateselect,format='(A9)'
close,31

; get doyselect (integer) and fsca_doy (decimal) corresponding to dateselect.
doyselect=fltarr(num_fsca)
for i=0,num_fsca-1 do begin
str=dateselect(i)
day=strmid(str,0,2)
mon=strmid(str,2,3)
year=strmid(str,5,4)
newstr='DOW '+mon+' '+day+' 00:00:00 '+year
bindate=bin_date(newstr)
binyear=bindate(0)
binmon=bindate(1)
binday=bindate(2)
doyselect(i)=julday(binmon,binday,binyear)-julday(1,1,binyear)+1; integer doy (starting from 1; good as array index).
endfor
fsca_doy=doyselect-1+overpass_time/24.0; decimal doy in UTC (starting from 0.0; used in time interpolation).

; read forden.
forden=fltarr(ncols_snodis,nrows_snodis)
if file_test(forden_in_dir+forden_in_file) then begin
openr,3,forden_in_dir+forden_in_file
readu,3,forden
close,3
endif
tmp_index=where(forden gt 0.9999,tmp_cnt)
if tmp_cnt ne 0 then forden(tmp_index)=0.9999; prevent forden=1 to avoid divide-by-zero error when applying viewable gap fraction correction.

; read fsca.
openr,11,fsca_in_dir+fsca_in_file
openw,12,temp_dir+'fsca.dat'
all_fsca_cube=assoc(11,fltarr(ncols_snodis,nrows_snodis))
fsca_cube=assoc(12,fltarr(ncols_snodis,nrows_snodis))
for i=0,num_fsca-1 do begin
    print,string(i+1,num_fsca,format='("[SNODIS info] step ",I0," of ",I0," in prepare_fsca_fscamask...")')
    i_in_all=doyselect(i)-1
    fsca=all_fsca_cube[i_in_all]; [0--1 non-dimensional].
    fsca=fsca/(1.0-forden); apply viewable gap fraction correction.
    ; correct for any unphysical values (i.e., >1.0) introduced by viewable gap fraction correction above.
    tmp_index=where(fsca gt 1.0,tmp_cnt)
    if tmp_cnt ne 0 then begin
       fsca[tmp_index]=1.0
    endif
    ; check for any wierd negative fsca.
    tmp_index=where(fsca lt 0.0,tmp_cnt)
    if tmp_cnt ne 0 then begin
       fsca[tmp_index]=0.0
    endif
    fsca_cube[i]=fsca
endfor

; read fscamask.
openr,21,fscamask_in_dir+fscamask_in_file
openw,22,temp_dir+'fscamask.dat'
all_fscamask_cube=assoc(21,fltarr(ncols_snodis,nrows_snodis))
fscamask_cube=assoc(22,fltarr(ncols_snodis,nrows_snodis))
for i=0,num_fsca-1 do begin
    i_in_all=doyselect(i)-1
    fscamask_cube[i]=all_fscamask_cube[i_in_all]
endfor

close,11,12,21,22

print,'[SNODIS info] ended running prepare_fsca_fscamask.'
end
