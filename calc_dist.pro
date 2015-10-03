;---------------------------------------------------------------------------------
; $Id: calc_dist.pro,v 1.2 2011/09/08 22:31:05 bguan Exp $
;
; Calculate great-circle distance on earth surface.
; lon0/lat0: Lon/Lat of first point; in degrees (must be a scalar or 1 element array). 
; lon1/lat1: Lon/Lat of second point; in degrees (can be an array).
; dist_km: great-circle distance between the two points; in km.
;
; Vincenty formula is used.
; Reference: http://en.wikipedia.org/wiki/Great-circle_distance
;
; Copyright (C) 2010. All rights reserved.
;---------------------------------------------------------------------------------
pro calc_dist,lon0,lat0,lon1,lat1,dist_km

pi=3.14159
mean_radius=6370.997; mean radius of earth in km.
phi0=lat0/180.0*pi
phi1=lat1/180.0*pi
lambda0=lon0/180.0*pi
lambda1=lon1/180.0*pi
dlambda=abs(lambda1-lambda0)
tmpA=cos(phi1)*sin(dlambda)
tmpB=cos(phi0)*sin(phi1)-sin(phi0)*cos(phi1)*cos(dlambda)
tmpC=tmpA^2+tmpB^2
nominator=sqrt(tmpC)
denominator=sin(phi0)*sin(phi1)+cos(phi0)*cos(phi1)*cos(dlambda)
dsigma=atan(nominator,denominator)
dist_km=dsigma*mean_radius

end
