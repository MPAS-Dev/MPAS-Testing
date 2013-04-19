clear all

% A simple plotting program to visualize the evolution of the baroclinic
% channel simulation. The field is read in, reshaped to be (nx,ny) and
% plotted for all times.
%
% USERS need to specify the following:
%   nVertLevels: the number of vertical levels in simulation
%   nx: the number of cells along the x-direction
%   ny: the number of cells along the y-direction
%   iLevel: the vertical level that you wish to visualize
%   var: the variable that you wish to visualize
%   file: the path to the output (or other file)
%
%   NOTE: nx * ny == nCells
%
% the default is to plot all data from 1 to Time from the netCDF file
% subsectioning is allowed by specifying nTimeMin (i.e. when to start)
% and nTimeMax (i.e. when to end). The actual start and end times are 
% determined via min/max comparisons to the netCDF file.

% 10km: nx=16, nx=50, 4km: nx=40, ny=125, 1km: nx=160, ny=500
%-------------------------------------------------------------------------

nVertLevels = 20
nx = 160
ny = 500
iLevel = 1
var = 'Vor_cell'
file = '../../1000m_20levs/se20_160_4procs/output.0000-01-01_00:00:00.nc'

%optional
nTimeMin = 10;
nTimeMax = 9e10;
%-------------------------------------------------------------------------

%open file
ncid_hex = netcdf.open(file,'nc_nowrite');

%get dimensions
[dimname, dimlen] = netcdf.inqDim(ncid_hex,0);

%get handle to var
ID_hex = netcdf.inqVarID(ncid_hex,var);

%read var and see how big it is
work = netcdf.getVar(ncid_hex,ID_hex);
a=size(work)

iTimeMin = max(1,nTimeMin)
iTimeMax = min(a(3),nTimeMax)
nTime = iTimeMax - iTimeMin + 1

%make workspace for reduced arrays
workq = zeros(a(2),nTime);
tmp=zeros(nx*ny,1);
workavg = zeros(nx,ny);

%put all data for iLevel into work array
workq(:,1:nTime) = work(iLevel,:,iTimeMin:iTimeMax);
clear work

%find min/max of var to set a single colorbar for entire movie
r = min(workq);
zmin = min(r)
r = max(workq);
zmax = max(r)

%build increments based on zmax and zmin
inc = (zmax - zmin) / 20;
zlevs = zmin:inc:zmax

%loop over time
for iTime=1:nTime
    
    %copy data for iTime into work array and reshape
    tmp(:)=workq(:,iTime);
    workavg=reshape(tmp,nx,ny);
    hex = workavg;

    % average data on every other row so it can be plotted as Cartesian
    for j=2:2:ny
     for i=2:nx-1
         hex(i,j) = (workavg(i+1,j)+workavg(i,j))/2.0;
     end
    end

    % plot the data
    b=hex;
    figure(1)
    b = transpose(b);
    contourf(b,zlevs)
    caxis([zmin zmax])
    colormap(jet)
    colorbar

end