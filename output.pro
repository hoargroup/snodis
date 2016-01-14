;---------------------------------------------------------------------------------
; $Id: output.pro,v 1.11 2012/10/29 23:17:12 bguan Exp $
; Extract daily variables at specified UTC hour.
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro output,varname

common param

in_dir=snodis_root+'intermediate/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
in_file=varname+'.dat'

out_dir=snodis_root+'output/'+area+'/'+strcompress(year,/remove_all)+run_name+'/'; DO include trailing slash.
out_file=varname+'.dat'

hour_to_extract=6; [integer UTC hour].

dir2=snodis_root+'output/'+area+'/'; DO include trailing slash.

;---------------------------------------------------------------------------------
; end user input.
;---------------------------------------------------------------------------------

print,'[SNODIS info] running output...'

openr,11,in_dir+in_file
swe_cube=assoc(11,fltarr(ncols_snodis,nrows_snodis))

if ~file_test(out_dir,/directory) then spawn,'mkdir -p '+out_dir
openw,12,out_dir+out_file
sweout_cube=assoc(12,fltarr(ncols_snodis,nrows_snodis))

i=0
while 1 do begin
   print,string(i+1,varname,format='("[SNODIS info] step ",I0," in output,",A,"...")')
   sweout_cube[i]=swe_cube[hour_to_extract+i*24]
   point_lun,-11,pos; get position of pointer in file unit 1.
   point_lun,11,pos+long64(24)*ncols_snodis*nrows_snodis*4; move pointer to the right by one day in file unit 1; note 64-bit integer used in calculation due to very large value.
   if eof(11) then break; if end-of-file encountered then exit loop.
   i++
end

close,11,12

;---------------------------------------------------------------------------------
; produce .ctl files for GrADS.
;---------------------------------------------------------------------------------
spawn,dir2+'mkctl.sh '+strcompress(year,/remove_all)

print,'[SNODIS info] ended running output.'
end
