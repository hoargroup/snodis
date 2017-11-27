clear;

 pni='/Volumes/hydroData/WestUS_Data/MODSCAG/UpperColoradoRiver/Geographic/';
    pno='/Volumes/COSWE/SWE_SNODIS/recon/snodis/input_fsca/';
    mkdir([pno,'UpperColoradoRiver/',num2str(yr)]);

for yr=2013:2013

    if(leapyear(yr))
        numdays=366;
    else
        numdays=365;
    end

    undefi=-9999;
    undefo=-9999;

    outfile=[pno,'UpperColoradoRiver/',num2str(yr),'/',num2str(yr),'.dat'];
    fid=fopen(outfile,'w');

    data=ones(1950,2580)*undefo;
    for cnt=1:numdays
        infile=[pni,num2str(yr),num2str(cnt,'%03i'),'.tif'];
        if(exist(infile,'file'))
            data=geotiffread(infile);
            data(data==undefi)=NaN;
            data=flipud(data);
            data=data';
            data(isnan(data))=undefo;
        end

        fwrite(fid,data,'real*4');
        disp([num2str(yr),num2str(cnt,'%03i'),'.tif processed; [',num2str(size(data)),'] elements written.' ]);

    end
fclose(fid);
end
disp('Done.');
