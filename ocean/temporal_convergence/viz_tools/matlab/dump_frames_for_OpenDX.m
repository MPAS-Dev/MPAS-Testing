
% This script open a output.nc file and writes out the output
% in ascii format to be read in by OpenDX

clear all

%-------------------------------------------------------------------------
% NOTE: relative to where this script is executed, we assume that the
% following directories exist:
%   ../OpenDX
%   ../OpenDX/movie
%   ../OpenDX/movie/data
%
% NOTE: we assume that the following files exist in ../OpenDX/movies
%   ocean.position.data
%   ocean.edge.data
%   ocean.loop.data
%   ocean.face.data
%
% All of the ocean.*.data files were created in when the basin mesh was
% created. These files are grid specific and can be found in
% branches/ocean_projects/basin/dx
%
% for baroclinic_channel test case, we generally have:
% 10km: nx=16, nx=50, 4km: nx=40, ny=125, 1km: nx=160, ny=500
%-------------------------------------------------------------------------

%-------------------------------------------------------------------------
% USERS: set the fields below here
%-------------------------------------------------------------------------

field3D=1            % set to 1 for 3D fields (like temperature) and 0 for 2D
iLevel = 1           % if field3D=1, this the level to be extracted
var = 'ke'     % this is the variable to be extracted (case sensitive)

periodic=0      % for channels or any planar re-entrant settings, periodic=1
nx=160          % when periodic == 1, must specify nx
ny=500          % when periodic == 1, must specify ny


% path the output netCDF file == resolution + time_step + output
resolution = '../..'
time_step = '/'
output = 'o.x5.NA.60km_10km.0005-01-01_00:00:00.nc'
file = [resolution '/' time_step '/' output]

% path to OpenDX basin files
dxpath = '../../../x5.NA.50km_10km.dx'

% if you don't want all time slices in output file, set the bounds here
% default is from 1 to number of time records in netCDF file
% so set nTimeMin<1 to start at beginning of output file
% and set nTimeMax to be very big to go to the end of output file
nTimeMin = -1;
nTimeMax = 9e10;


%OpenDX sometimes has problems with very small numbers
replaceSmallNumbers = 0;        % set to one to replace small numbers
eps = 1.0e-12;                  % small numbers are set to this value

%-------------------------------------------------------------------------
%  USERS: no routine edits below here
%-------------------------------------------------------------------------



% OpenDX requires the first data field to be labeled with 0
% so nTimeShift makes sure this is the case (not fully implemented)
if nTimeMin > 1
    nTimeShift = -nTimeMin;
else
    nTimeShift = 0;
end

% data will be masked in OpenDX based on this value
% this value must be hardwired into OpenDX, so change only when necessary
mask_value = -1499.0

% get a handle to the ouptut netCDF file
ncid = netcdf.open(file,'nc_nowrite')

% get some dimensions
[TimeName, TimeLength] = netcdf.inqDim(ncid,1);
[nCellsName, nCells] = netcdf.inqDim(ncid,2);
[nEdgesName, nEdges] = netcdf.inqDim(ncid,3);
[nVerticesName, nVertices] = netcdf.inqDim(ncid,7);
[nVertLevelsName, nVertLevels] = netcdf.inqDim(ncid,13);

% get nEdgesOnCell. sum(nEdgesOnCell) is exported to OpenDX files
varID = netcdf.inqVarID(ncid,'nEdgesOnCell');
[varName,xtype,dimids,natts] = netcdf.inqVar(ncid,varID);
[numdims, numvars, numglobalatts, unlimdimID] = netcdf.inq(ncid);
nEdgesOnCell =  netcdf.getVar(ncid,varID);

% get the depth of each column. cells below bottom are masked in OpenDX
varID = netcdf.inqVarID(ncid,'maxLevelCell');
[varName,xtype,dimids,natts] = netcdf.inqVar(ncid,varID);
[numdims, numvars, numglobalatts, unlimdimID] = netcdf.inq(ncid);
maxLevelCell =  netcdf.getVar(ncid,varID);

% find the starting and ending time as measured in the netCDF file
iTimeMin = max(1,nTimeMin)
iTimeMax = min(TimeLength,nTimeMax)
nTime = iTimeMax - iTimeMin + 1

% OK, get the data field (var) to be dumped to files
varID = netcdf.inqVarID(ncid,var);
[varName,xtype,dimids,natts] = netcdf.inqVar(ncid,varID);
[numdims, numvars, numglobalatts, unlimdimID] = netcdf.inq(ncid);
var =  netcdf.getVar(ncid,varID);
a=size(var)

% see if the specified min/max times are smaller than what is in the file
iTimeMin = max(1,nTimeMin)
if field3D == 1
    iTimeMax = min(a(3),nTimeMax)
else
    iTimeMax = min(a(2),nTimeMax)
end
nTime = iTimeMax - iTimeMin + 1

% we assume that ../OpenDX/movie exists
% remove OpenDX files in that directory
system('rm -f ../OpenDX/movie/list.dx')
system('rm -f ../OpenDX/movie/data/*.data')
system('rm -f ../OpenDX/movie/*.dx')
system('rm -f ../OpenDX/movie/*.data')
str1 = [ 'cp ' dxpath '/ocean.dx ../OpenDX/movie/.' ]
str2 = [ 'cp ' dxpath '/ocean.position.data ../OpenDX/movie/.' ]
str3 = [ 'cp ' dxpath '/ocean.face.data ../OpenDX/movie/.' ]
str4 = [ 'cp ' dxpath '/ocean.loop.data ../OpenDX/movie/.' ]
str5 = [ 'cp ' dxpath '/ocean.edge.data ../OpenDX/movie/.' ]
system(str1)
system(str2)
system(str3)
system(str4)
system(str5)

% build the header of list.dx file (this is the file that OpenDX will open)
f1 = '../OpenDX/movie/list.dx'
fid = fopen(f1, 'w');

fprintf(fid, 'object "positions list" class array type float rank 1 shape 3 items %d \n', sum(nEdgesOnCell))
fprintf(fid, 'ascii data file ocean.position.data\n')
fprintf(fid, '\n')

fprintf(fid, 'object "edge list" class array type int rank 0 items  %d \n', sum(nEdgesOnCell))
fprintf(fid, 'ascii data file ocean.edge.data\n')
fprintf(fid, 'attribute "ref" string "positions"\n')
fprintf(fid, '\n')

fprintf(fid, 'object "loops list" class array type int rank 0 items %d \n', nCells)
fprintf(fid, 'ascii data file ocean.loop.data\n')
fprintf(fid, 'attribute "ref" string "edges"\n')
fprintf(fid, '\n')

fprintf(fid, 'object "face list" class array type int rank 0 items %d \n', nCells)
fprintf(fid, 'ascii data file ocean.face.data\n')
fprintf(fid, 'attribute "ref" string "loops"\n')
fprintf(fid, '\n')

varName = 'scalar'

% dump the sequence of data to ../OpenDX/movie/data
for iTime=iTimeMin:iTimeMax
    
    if(iTime > 1001); quit; end;
     if(iTime < 1001) 
        stringTime =  strcat('0000', int2str(iTime-1));
     end;
     if(iTime < 101) 
        stringTime = strcat('00000', int2str(iTime-1));
     end;
     if(iTime < 11) 
        stringTime = strcat('000000', int2str(iTime-1));
     end;
    
    FileName = strcat('../OpenDX/movie/data/', varName, '.', stringTime)
    F1 =  strcat('./data/', varName, '.', stringTime)
    
    if field3D == 1
        x = var(iLevel,:,iTime+nTimeShift);
    else
        x = var(:,iTime+nTimeShift);
    end
    
    % the following will mask the first and last column (entry and exit)
    % the masking takes place in OpenDX based on mask_value
    if periodic == 1
        work = reshape(x,nx,ny);
        work(1,:)= mask_value;
        work(nx,:)= mask_value;
        x=reshape(work,1,nx*ny);
    end
    
    % the following will mask values below ocean bottom
    % the masking takes place in OpenDX based on mask_value
    if field3D == 1
    for i=1:nCells
        if maxLevelCell(i) < iLevel
            x(1,i) = mask_value;
        end
    end
    end
    
    
    % the following will replace small abs number with user specified value
    if replaceSmallNumbers == 1
        for i=1:nCells
            r = abs(x(1,i));
            if r < eps
                x(1,i) = eps;
            end
        end
    end
    
   
    dlmwrite(FileName, x, 'delimiter', '\t');
    
    fprintf(fid,'object %i  class array type float rank 0 items %d \n', iTime-1, nCells)
    fprintf(fid,'data file %s\n', F1)
    fprintf(fid, 'attribute "dep" string "faces"\n')
    fprintf(fid, '\n')

end


for iTime=iTimeMin:iTimeMax
     if(iTime > 1001); quit; end;
     if(iTime < 1001) 
        stringTime =  strcat('0000', int2str(iTime-1));
     end;
     if(iTime < 101) 
        stringTime = strcat('00000', int2str(iTime-1));
     end;
     if(iTime < 11) 
        stringTime = strcat('000000', int2str(iTime-1));
     end;

     VarName = strcat('"',varName, stringTime, '"')
     fprintf(fid, 'object %s class field\n',VarName)
     fprintf(fid, 'component "positions"     "positions list"\n')
     fprintf(fid, 'component "edges"         "edge list"\n')
     fprintf(fid, 'component "loops"         "loops list"\n')
     fprintf(fid, 'component "faces"         "face list"\n')
     fprintf(fid, 'component "data"          %i\n', iTime-1)
    fprintf(fid, '\n')

end

fprintf(fid, 'object "smovie" class series\n')
for iTime=iTimeMin:iTimeMax
     if(iTime > 1001); quit; end;
     if(iTime < 1001) 
        stringTime =  strcat('0000', int2str(iTime-1));
     end;
     if(iTime < 101) 
        stringTime = strcat('00000', int2str(iTime-1));
     end;
     if(iTime < 11) 
        stringTime = strcat('000000', int2str(iTime-1));
     end;

     VarName = strcat('"',varName, stringTime, '"')
     fprintf(fid, 'member %i value %s position %i\n',iTime-1, VarName, iTime-1)

end

% put some data into ocean.area.data to be visualized with snapshot.net
system('cp ../OpenDX/movie/data/scalar.0000001 ../OpenDX/movie/ocean.area.data')

fclose(fid);