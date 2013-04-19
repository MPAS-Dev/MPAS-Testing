implicit none
real (kind=4), allocatable, dimension(:) :: x,y, work_kmt
real (kind=4), allocatable, dimension(:,:) :: ztopo
integer :: nx, ny, inx, iny, ix, iy, kmt_neighbor_max
real :: pi, dtr, zdata, rlon, rlat, r, ymin, ymax, xmin, xmax, xmid, sigma
real :: latmin, latmax, lonmin, lonmax
logical :: flag, kmt_flag
pi = 4.0*atan(1.0)
dtr = pi / 180.0

allocate(kmt(nCells))
kmt = 0
zdata = 0.0

kmt = nVertLevelsMOD

xmin = minval(xCell)
xmax = maxval(xCell)
xmid = (xmax-xmin)/2.0
sigma = (xmin-xmax)/10.0

do iCell=1,nCells
    zdata = 5000.0-*RIDGE*exp(-2.0*((xCell(iCell)-xmid)/sigma)**2)
    r = 0
    kmt_flag=.false.
    do k=1,nVertLevelsMod
        if(.not.kmt_flag) then
            r = r + dz(k)
            r = r + h_total_max / nVertLevelsMOD
            if(r.gt.zdata) then
                kmt(iCell) = k
                kmt_flag = .true.
            endif
        endif
    enddo
enddo

! solid boundary in y
ymin = minval(yCell)
write(6,*) ' minimum yCell ', ymin
ymax = maxval(yCell)
write(6,*) ' maximum yCell ', ymax
where(yCell.lt.1.001*ymin) kmt = 0
where(yCell.gt.0.999*ymax) kmt = 0

allocate(work_kmt(nCells))
work_kmt = 0.0
where(kmt.eq.0) work_kmt=1.0
write(6,*) 'number of cells culled ',sum(work_kmt)
deallocate(work_kmt)


