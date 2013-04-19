implicit none
real (kind=4), allocatable, dimension(:) :: x,y, work_kmt
real (kind=4), allocatable, dimension(:,:) :: ztopo
integer :: nx, ny, inx, iny, ix, iy, kmt_neighbor_max
real :: pi, dtr, zdata, rlon, rlat, r, ymin, ymax, xmin, xmax, xmid
real :: latmin, latmax, lonmin, lonmax
real :: min_depth
logical :: flag, kmt_flag
pi = 4.0*atan(1.0)
dtr = pi / 180.0

allocate(kmt(nCells))
kmt = 0

min_depth = *MIN_DEPTH

kmt = nVertLevelsMOD
if(on_a_sphere.eq.'YES              ') then
    write(6,*) 'Working on a sphere'
    latmin = -30*dtr
    latmax = +30*dtr
    lonmin = +10*dtr
    lonmax = +70*dtr
    write(6,*) ' lat min ', latmin
    write(6,*) ' lat max ', latmax
    where(latCell.lt.latmin) kmt = 0
    where(latCell.gt.latmax) kmt = 0
    where(lonCell.lt.lonmin) kmt = 0
    where(lonCell.gt.lonmax) kmt = 0

else
    ! solid boundary in y
    ymin = minval(yCell)
    ymax = maxval(yCell)
    xmin = minval(xCell)
    xmax = maxval(xCell)
    xmid = (xmax - xmin)/2.0

    do iCell=1,nCells
      if ( xCell(iCell).gt.(xmid-(xmax-xmin)/8.0) .and. xCell(iCell).lt.(xmid+(xmax-xmin)/8.0)) then
        zdata = (nVertLevelsMod - min_depth) * exp(-(xCell(iCell)-xmid)**2/(2*((xmax-xmin)/16.0))**2)

        kmt(iCell) = nVertLevelsMod - zdata
      endif
    enddo
    where(yCell.lt.1.001*ymin) kmt = 0
    where(yCell.gt.0.999*ymax) kmt = 0
endif


allocate(work_kmt(nCells))
work_kmt = 0.0
where(kmt.eq.0) work_kmt=1.0
write(6,*) 'number of cells culled ',sum(work_kmt)
deallocate(work_kmt)

