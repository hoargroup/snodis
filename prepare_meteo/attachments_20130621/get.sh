for year in {2012..2012}
do

mkdir -p $year
cd $year

startdate=1
enddate=365
if [ $year -eq 2000 ]; then
enddate=366
fi
if [ $year -eq 2004 ]; then
enddate=366
fi
if [ $year -eq 2008 ]; then
enddate=366
fi
if [ $year -eq 2012 ]; then
enddate=366
fi

for day in `seq $startdate $enddate`
do

if [ $day -lt 10 ]; then
wget -a ../log.txt -c ftp://hydro1.sci.gsfc.nasa.gov/data/s4pa/NLDAS/NLDAS_FORA0125_H.002/$year/00$day/NLDAS_FORA0125_*.grb
fi
if [ $day -ge 10 -a $day -lt 100 ]; then
wget -a ../log.txt -c ftp://hydro1.sci.gsfc.nasa.gov/data/s4pa/NLDAS/NLDAS_FORA0125_H.002/$year/0$day/NLDAS_FORA0125_*.grb
fi
if [ $day -ge 100 ]; then
wget -a ../log.txt -c ftp://hydro1.sci.gsfc.nasa.gov/data/s4pa/NLDAS/NLDAS_FORA0125_H.002/$year/$day/NLDAS_FORA0125_*.grb
fi

done

cd ..

done

date > Finished.txt
