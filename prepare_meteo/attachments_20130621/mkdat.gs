say 'This is to subset the data (which will be used as input to SNODIS).'

'reinit'

'open ../NLDAS_2012.ctl'

'set t 1 last'
'set lon -112.1875 -104.1875'
'set lat 33.0625 43.6875'

undefo=-9999

* .dat, .ctl
'save -v apcpsfc -n precip -u 'undefo' -o precip'
'save -v SPFH2m -n spehum -u 'undefo' -o spehum'
'save -v TMP2m -n sat -u 'undefo' -o sat'
'save -v mag(UGRD10m,VGRD10m) -n windspeed -u 'undefo' -o windspeed'
'save -v DSWRFsfc -n goes -u 'undefo' -o goes'
'save -v DLWRFsfc -n dlwrf -u 'undefo' -o dlwrf'
'save -v PRESsfc -n ps -u 'undefo' -o ps'

* netCDF
*'precip=apcpsfc'
*'save -v precip -f netCDF -u 'undefo' -o precip'
*'undefine precip'
*'spehum=SPFH2m'
*'save -v spehum -f netCDF -u 'undefo' -o spehum'
*'undefine spehum'
*'sat=TMP2m'
*'save -v sat -f netCDF -u 'undefo' -o sat'
*'undefine sat'
*'windspeed=mag(UGRD10m,VGRD10m)'
*'save -v windspeed -f netCDF -u 'undefo' -o windspeed'
*'undefine windspeed'
*'goes=DSWRFsfc'
*'save -v goes -f netCDF -u 'undefo' -o goes'
*'undefine goes'

say 'Done.'
say 'Note: need to fix XDEF.'
'!find . -name "*.ctl"|xargs grep -l "112.188"|xargs sed -i -e "s/112.188/112.1875/g"'
