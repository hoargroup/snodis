# This script exclusively works with data downloaded from JPL Snow.
# Run this from your computer. Currently set up for Mac with hydroData mounted as a server.

pnmain=/Volumes/hydroData/WestUS_Data/MODSCAG
domain=UpperColoradoRiver
pin=modscag-historic

for yr in {2013..2013}; do
pn=$pnmain/$pin/$yr
#mkdir -p /0UCO/Geographic

for doy in {001..366}; do
doy=`printf "%003d" ${doy}`

if [ -f $pnmain/$domain/Geographic/${yr}${doy}.tif ]; then
rm $pnmain/$domain/Geographic/${yr}${doy}.tif
fi

fn=`ls $pnmain/$pin/$yr/$doy/*snow_fraction.tif`

gdalwarp -te -112.25 33.0 -104.125 43.75 -tr 0.004166666666667 0.004166666666667 -r near -t_srs '+proj=longlat +datum=NAD83'  -dstnodata -9999 -ot Int16 ${fn} $pnmain/$domain/Geographic/${yr}${doy}.tif
# -te sets xmin, ymin, xmax, ymax as the extents. It should be in the reference system of the resultant file (in this case geographic lat/long)
# -tr sets the resolution of the grid. 0.004166666666 is 15/3600 which is the native resolution of modis
# -r sets the resampling method. we used nearest neighbor because there are classified values for clouds and miissing error that shouldn't be interpolated.
# -t_srs setes the projection system for the output file
# -dstnodata sets the no data value in the output file.
# -ot sets the data type
# see the gdalwarp documentation for more details


done # doy loop

done # year loop
