// This script will only run on google earth engine but is here for preservation's sake. And actually, google changed their api since this file was written so it needs to be updated to actually run.

// get hansen collection images
var gfcImage = ee.Image('UMD/hansen/global_forest_change_2013');

//set domain boundaries of interest
var lat2=43.75
var lat1=33.0
var lon2=-104.125
var lon1=-112.25

//creates feature polygon
var domain_coords=[[lon2, lat2], [lon2, lat1], [lon1, lat1],[lon1,lat2]]
var uco = ee.Feature.Polygon(domain_coords);
//var uco = ee.FeatureCollection([
  //ee.Feature.Polygon(domain_coords)]);

//select the various bands of the treecover dataset
var treeCover = gfcImage.select(['treecover2000']).clip(uco);
var lossImage = gfcImage.select(['loss']).clip(uco);
var gainImage = gfcImage.select(['gain']).clip(uco);
var lossYear = gfcImage.select(['lossyear']).clip(uco);
// Use the and() method to create the lossAndGain image.
var gainAndLoss = gainImage.and(lossImage);

print(treeCover.getInfo())

/* //This is all mapping
addToMap(treeCover.mask(treeCover),
         {'min': 0, 'max': 100, 'palette': '000000, 00FF00'},
         'Tree Cover in the Upper Colorado River Basin');
centerMap( -108,38,6);


// Add the loss layer in red
addToMap(lossImage.mask(lossImage),
        {'palette': 'FF0000'},
        'Loss');

// Add the gain layer in blue
addToMap(gainImage.mask(gainImage),
          {'palette': '0000FF'},
           'Gain');

var gaincnt = gainImage.reduceRegion({
  'reducer': ee.Reducer.sum(),
  'geometry': uco,
  'maxPixels': 2e9});

print(gaincnt.getInfo());
//576495 pixels have gains. 0.5% of pixels

//count gain and loss pixels
var cnt = gainAndLoss.reduceRegion({
  'reducer': ee.Reducer.sum(),
  'geometry': uco,
  'maxPixels': 2e9});

print(cnt.getInfo());
// only 4410 pixels in uco have both gain and loss.

// Show the loss and gain image
addToMap(gainAndLoss.mask(gainAndLoss),
           {'palette': 'FF00FF'},
            'Gain and Loss');
*/

//export known 2000 tree cover
exportImage(treeCover.uint8,'treecover2000_30m',
{ 'region': domain_coords,
  'driveFolder':'earthengine',
  'maxPixels': 2e9,
  'crs': "EPSG:4326",
  'dimensions':JSON.stringify([32500, 43000]),
  'crs_transform': JSON.stringify([0.0002777777777777778,0,-112.25, 0,-0.0002777777777777778,43.75])
});

//for 500 meter output use this. will resample with nearest neighbor
//'dimensions': JSON.stringify([1950, 2580]),
//'crs_transform': JSON.stringify([15/3600,0,-112.25, 0,-15/3600,43.75])});


// for loop looks for loss pixels each year and
//adds these lost pixels to the treecover image iteratively
var gainonly = gainImage.where(gainAndLoss.eq(1),0)

/* // Add the gain only layer in blue
addToMap(gainonly.mask(gainonly),
          {'palette': 'FFFFFF'},
           'Gain Only');

// count gain only pixels
var gaincnt = gainonly.reduceRegion({
  'reducer': ee.Reducer.sum(),
  'geometry': uco,
  'maxPixels': 2e9});
print(gaincnt.getInfo())
*/


var foresti = treeCover
var forest = treeCover.where(gainImage.eq(1),treeCover.add(0.1));//add 0.1% to pixels with gains incase they start at 0 (for multiplier below)

for (var yr = 1; yr<=12; yr++){

var num=2000+yr
//print(num);
var fn = 'treecover'+num+'_30m'

//add some percent to canopy for pixels that gained canopy. 5%?
foresti = forest.where(gainImage.eq(1),forest.multiply(1.05))
foresti = foresti.where(foresti.gt(100),100)//clamp to 100%

// Check for loss in year and previous years
var lossinyr = lossYear.eq(yr)
var lossprev = lossYear.lt(yr)

// Now create an image like the forest image, except with zeros
// where the lossinyr image has the value 1.
foresti = foresti.where(lossinyr.eq(1), forest.multiply(0.25));//canopy is reduced to 25% of what it was
foresti = foresti.where(lossprev.eq(1), forest);//assuming no canopy recovery once lost

forest=foresti;//save canopy state before moving to next year
//print(forest.getInfo())

exportImage(forest.uint8,fn,
{ 'region': domain_coords,
  'driveFolder':'earthengine',
  'maxPixels': 2e9,
  'crs': "EPSG:4326",
  'dimensions':JSON.stringify([32500, 43000]),
  'crs_transform': JSON.stringify([0.0002777777777777778,0,-112.25, 0,-0.0002777777777777778,43.75])
});

//use this for 500m output. nearest neighbor resampling.
//'dimensions': JSON.stringify([1950, 2580]),
//'crs_transform': JSON.stringify([15/3600,0,-112.25, 0,-15/3600,43.75])




}

/*
  var tcavg = treeCover.reduceRegion({
  'reducer': ee.Reducer.mean(),
  'geometry': uco,
  'bestEffort': true});

 print(tcavg.getInfo())
*/
