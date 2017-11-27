#! /bin/bash

# This file is designed to mosaic and reproject the output files from google earth engine to the domain and resolution desired.


# Define the input and output folders
pnmain='.'
pni=${pnmain}/raw
pno=${pnmain}/UpperColoradoRiver

#
for yr in {2000..2012};
do
echo $yr
mkdir -p $pno

#removes an existing tif file
if [ -f $pno/uco_umdforden${yr}.tif ]; then
rm $pno/uco_umdforden${yr}.tif
fi


fns=`find $pni -name "treecover${yr}*.tif"`

#test for a non-empty array and create tiff if you have hdf data
#if [[ "${fns}" =~ "" ]]; then
echo $fns
gdalwarp -of GTiff -te -112.25 33.0 -104.125 43.75 -tr 0.004166666666667 0.004166666666667 -r average -t_srs '+proj=longlat +datum=NAD83'  -dstnodata -9999 -ot Int16 ${fns} $pno/uco_umdforden${yr}.tif
#fi

done

printf "\n**** Done. ****\n"
