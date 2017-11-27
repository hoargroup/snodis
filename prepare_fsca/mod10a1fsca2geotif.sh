#! /bin/bash

# This script is designed to read the raw .hdf files from MOD10a1, extract fsca, and reproject to geographic system for the domain of interest. I ran this with snowserver mounted locally. Originally by Theo Barnhart (I think)

# ** Define the location of raw .hdf files
pnmain=/Volumes/hydroData/WestUS_Data/MOD10A1
pni=${pnmain}/raw
domain=UpperColoradoRiver
pno=${pnmain}/$domain


## ------> Method 1
band=:MOD_Grid_Snow_500m:Fractional_Snow_Cover # set the band you want to build VRTs for
bnd_shrt=fsca # short name for the band you want to extract
prodname=MOD10A1 # nasa /usgs product name

for yr in {2000..2013};
 do
 for doy in {054..060};
 do
 doy=`printf "%003d" ${doy}` #sometimes needed...not sure when.

 echo $yr $doy

 #removes an existing tif file
 if [ -f $pno/Geographic/${yr}${doy}.tif ]; then
 rm $pno/Geographic/${yr}${doy}.tif
 fi

 #HDF4_EOS:EOS_GRID:"${fn}":MOD_Grid_Snow_500m:Fractional_Snow_Cover
 #hdf_fn=`find $pni/$yr -name "MOD10A1.A$yr$doy.*.hdf"`

 i=0
 inputmap=()
 for f in `find $pni/$yr -name "MOD10A1.A$yr$doy.*.hdf"`
 do
inputmap[$i]=`gdalinfo $f | grep SUBDATASET_${SDSnum}_NAME= | sed -e s/SUBDATASET_${SDSnum}_NAME=//`
 i=$((i + 1))
  done

 #Method 1
 #this makes a temporary file on your harddrive. use this method fi you want a virtual raster of all the tiles.
 fnvrt=$prodname.$bnd_shrt.vrt
 gdalbuildvrt -overwrite $fnvrt ${inputmap[@]}
 gdalwarp -of GTiff -te -112.25 33.0 -104.125 43.75 -tr 0.004166666666667 0.004166666666667 -r near -t_srs '+proj=longlat +datum=WGS84'  -dstnodata -9999 -ot Int16 $fnvrt $pno/Geographic/${yr}${doy}.tif

 done
 done

 rm $fnvrt




printf "\n**** Done. ****\n"
