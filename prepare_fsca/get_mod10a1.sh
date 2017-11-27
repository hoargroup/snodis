year=2000

mkdir -p $year
cd $year

for month in {01,02,03,04,05,06,07,08,09,10,11,12}; do
for day in {01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31}; do
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h09v05.005.*.hdf
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h09v04.005.*.hdf
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h08v04.005.*.hdf
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h08v05.005.*.hdf
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h10v04.005.*.hdf
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h10v05.005.*.hdf
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h09v05.005.*.hdf.xml
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h09v04.005.*.hdf.xml
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h08v04.005.*.hdf.xml
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h08v05.005.*.hdf.xml
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h10v04.005.*.hdf.xml
wget ftp://n4ftl01u.ecs.nasa.gov/SAN/MOST/MOD10A1.005/$year.$month.$day/MOD10A1.A???????.h10v05.005.*.hdf.xml
done
done
