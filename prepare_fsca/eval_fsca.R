#eval_fsca
#Dominik Schneider, 2014
#adapted from a GraDS Script from Bin Guan at JPL

# This script lets you manually see and choose which modscag images are good enough to use, e.g. in the reconstruction. This will go through the files in the directory specified for the dates specified and write the dates you choose to a text file.

# 2 to select modscag as-is
# 3 to select modscag with mod10a1 cloudmask
# 4 to select modscag with sensor zenith filter
# enter to skip image
# b to break out of loop and just save the dates you've chosen.


require(lubridate)
require(raster)

setwd("/Volumes/hydroData/WestUS_Data/")
pn_modscag='MODSCAG/UpperColoradoRiver/Geographic'
pn_mod10a1='MOD10A1/UpperColoradoRiver/Geographic'
pn_mod09ga='MOD09GA/SensorZenith/UpperColoradoRiver/Geographic'
pn_touse='UCO_FSCA'

wdt=sdt=as.POSIXct('2012-January-1',format='%Y-%B-%d',tz='MST')
edt=as.POSIXct('2012-August-31',format='%Y-%B-%d',tz='MST')
#file.remove(paste(pn_touse,'/',year(wdt),'.txt',sep=''))


uinput <- function() {
    input <- NA
    cat(paste(strftime(wdt,'%b %d, %Y'),': 2, 3, or 4 to keep an image, enter to continue to next image: '))
    input <- readline()
    
    if(input == 2) {
        write.table(toupper(strftime(wdt,'%d%b%Y')),condates,sep='\r\n',append=T,row.names=F,col.names=F,quote=F)
        
        file.symlink(fn_modscag[fig],file.path(pn_touse,strftime(wdt,'%Y%j.tif')))
        return(input)
        
    } else if(input==3) {
        write.table(toupper(strftime(wdt,'%d%b%Y')),condates,sep='\r\n',append=T,row.names=F,col.names=F,quote=F)
        
        writeRaster(rg2,filename=file.path(pn_touse,strftime(wdt,'%Y%j.tif')))
        
        return(input)
        
    } else if (input==4){
        
        write.table(toupper(strftime(wdt,'%d%b%Y')),condates,sep='\r\n',append=T,row.names=F,col.names=F,quote=F)
        
        rg3[rg3==150]=202
        writeRaster(rg3,filename=file.path(pn_touse,strftime(wdt,'%Y%j.tif')))
        
        return(input)
    } else if(input=='b'){
        return(10)
    } else {
        return(0)
    }
}

fn_modscag=list.files(pn_modscag,full.names=T)
fn_mod10a1=list.files(pn_mod10a1,full.names=T)
fn_mod09ga=list.files(pn_mod09ga,full.names=T)

while (wdt <= edt){

    condates=file(paste(pn_touse,'/',year(wdt),'.txt',sep=''),open='at')
    connotes=file(paste(pn_touse,'/',year(wdt),'-notes.txt',sep=''),open='at')

    
    fig=grep(strftime(wdt,'%Y%j.tif'),fn_modscag)
    fi1=grep(strftime(wdt,'%Y%j.tif'),fn_mod10a1)
    fi9=grep(strftime(wdt,'%Y%j.tif'),fn_mod10a1)
    
    rg=r1=raster(nrows=2580,ncols=1950, xmn=-112.25, xmx=-104.125, ymn=33,ymx=43.75)#initialize so it prints an empty raster if file doesn't exist
    values(rg) <- values(r1) <- 250
    projection(rg) <- projection(r1) <- '+proj=longlat +datum=WGS84'
    
    if(length(fig)==0){
        cat(paste('modscag ',strftime(wdt,'%d%b%Y'),' (doy ',strftime(wdt,'%j'),') does not exist\n',sep=''))
    } else {
            rg=raster(fn_modscag[fig])
            projection(rg)='+proj=longlat +datum=WGS84'
        }
    
        if(length(fi1)==0){
            cat(paste('mod10a1 ',strftime(wdt,'%d%b%Y'),' (doy ',strftime(wdt,'%j'),') does not exist\n',sep=''))
        } else {
            r1=raster(fn_mod10a1[fi1],crs='+proj=longlat +datum=WGS84')
            projection(r1)='+proj=longlat +datum=WGS84'
        }

    if(length(fi9)==0){
        cat(paste('mod09ga ',strftime(wdt,'%d%b%Y'),' (doy ',strftime(wdt,'%j'),') does not exist\n',sep=''))
        } else {
            r9=raster(fn_mod09ga[fi9],crs='+proj=longlat +datum=WGS84')
            projection(r9)='+proj=longlat +datum=WGS84'
        }
        
    if(length(fig) == 0 & length(fi1)==0){
        ## writeRaster(rg,filename=file.path(pn_touse,strftime(wdt,'%Y%j.tif')))
        wdt=wdt+days(1)
        next
    }
    
    rg3=rg2=rg
    rg2[r1==250]=250
    rg2[r1==201]=201

    rg3[(r9*0.01)>30]=150

    
    par(mfcol=c(1,4))
    plot(r1,main=paste('mod10a1\n',strftime(wdt,'%d%b%Y')),colNA='black')
    plot(rg,main=paste('modscag\n',strftime(wdt,'%d%b%Y')),colNA='black') 
    plot(rg2,main=paste('modscag with mod35 mask\n',strftime(wdt,'%d%b%Y')),colNA='black')
    plot(rg3,main=paste('modscag with sensor zenith filter\n',strftime(wdt,'%d%b%Y')),colNA='black',zlim=c(0,250))

    if(uinput()==10){
        close(condates)
        close(connotes)
        break
     }
    cat('enter notes about image: ')
    notes <- readline()
    
write.table(paste(toupper(strftime(wdt,'%d%b%Y')),' - ',notes,sep=''),connotes,sep='\r\n',append=T,row.names=F,col.names=F,quote=F)

    close(condates)
    close(connotes)

    wdt=wdt+days(1)
}



dir.create(paste(pn_touse,'/',year(wdt),'_finished_',strftime(now(),'%Y%m%d_%H%M'),sep=''))
file.symlink(file.path('..','..','MODSCAG'), paste0(pn_touse,'/',year(wdt),'_finished_',strftime(now(),'%Y%m%d_%H%M'),'/','MODSCAG'))
file.rename(paste(pn_touse,'/',year(wdt),'.txt',sep=''),paste(pn_touse,'/',year(wdt),'_finished_',strftime(now(),'%Y%m%d_%H%M'),'.txt',sep=''))

setwd('~/Documents/SWEReconstruction')
