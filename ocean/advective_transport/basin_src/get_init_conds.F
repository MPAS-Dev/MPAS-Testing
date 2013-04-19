implicit none
real :: halfwidth, dtr, pi, p(3), q(3), xin, yin, zin, ulon, ulat, stress, n1, n2, distance, r, temp_t, temp_s, d
real :: dotProd, xmin, xmax, xmid, ymin, ymax, ymid
real :: r0, delta, umax
real, dimension(:), allocatable :: psiVertex
integer :: iTracer, ix, iy, ndata, i, j, k, ixt, iyt, ncull, jcount, iNoData, kdata(nVertLevelsMod)
logical :: flag_lat

real :: a, omega0, gh0

pi = 4.0*atan(1.0)
dtr = pi/180.0

hNew = h_total_max
temperatureNew = 1.0
salinityNew = 1.0
tracer1New = 0.0
uNew = 0

write(6,*) ' not using real bathymetry'

fEdgeNew(:) = 0.0
fVertexNew(:) = 0.0
bottomDepthNew(:) = 0.0
uNew(:,:,:) = 0.0

! basin-mod
! setting for three levels - Set h values for isopycnal system
write(6,*) ' setting three levels for isopycnal system'
do i = 1, nVertLevelsMOD
    hNew(1,i,:) = h_total_max / nVertLevelsMOD
    hZLevel(i) = h_total_max / nVertLevelsMOD
end do

bottomDepthNew(:) = h_total_max

! basin-mod
!Specify Density values for isopycnal levels
write(6,*) ' setting density'
rhoNew(1,:,:) = 1000.0

! basin-mod
! set temperature for isopycnal levels
write(6,*) ' setting temperature'
temperatureNew(1,:,:) = 35.0

! basin-mod
! set salinity for levels
salinityNew(1,:,:) = 35.0

! Updating density with linear EOS
do i = 1,nCellsNew
  rhoNew(1,:,i) = 1000.0*(1.0 - 2.5e-4*temperatureNew(1,1,i) + 7.6e-4*salinityNew(1,1,i))
enddo

! basin-mod
! set forcing for isopycnal levels
write(6,*) 'setting u_src - wind forcing'
u_srcNew = 0.0
write(6,*) ' u_srcNew ', minval(u_srcNew), maxval(u_srcNew)

! Set initial velocitiy field for solid body rotation
xmin = minval(xCellNew)
xmax = maxval(xCellNew)
xmid = (xmax + xmin)/2.0

ymin = minval(yCellNew)
ymax = maxval(yCellNew)
ymid = (ymax + ymin)/2.0

d = 75
allocate(psiVertex(nVerticesNew))
r0 = 140.0
delta = 0.05
omega0 = 2.0 * pi / (2.0 * 60.0 * 60.0) ! one revolution of a circle in 2 hours 

do iVertex = 1, nVerticesNew
    xin = xVertexNew(iVertex) - xmid
    yin = yVertexNew(iVertex) - ymid

    r = sqrt(xin**2 + yin**2)/r0 ! nondimensional radial distance

    psiVertex(iVertex) = omega0*r0**2/4.0*(r**2 - (r + 1)*sqrt((r-1)**2 + delta**2) + delta**2*log((r - 1) + sqrt((r-1)**2 + delta**2)))
end do

do iEdge = 1, nEdgesNew
  iVertex1 = verticesOnEdgeNew(1, iEdge)
  iVertex2 = verticesOnEdgeNew(2, iEdge)

  xin = xEdgeNew(iEdge) - xmid
  yin = yEdgeNew(iEdge) - ymid
  distance = sqrt(xin**2 + yin**2)

  xin = xin/distance
  yin = yin/distance

  zin = xin ! temp storage

  xin = -yin ! xnew = -yold
  yin = zin ! really ynew = xold
  zin = 0.0

  dotProd = normalsNew(1, iEdge)*xin + normalsNew(2, iEdge)*yin + normalsNew(3, iEdge)*zin

  r = sqrt( (xEdgeNew(iEdge) - xmid)**2 + (yEdgeNew(iEdge) - ymid)**2)

  uNew(1, :, iEdge) = - 1.0 * (psiVertex(verticesOnEdgeNew(2, iEdge)) - psiVertex(verticesOnEdgeNew(1, iEdge))) / (dvEdgeNew(iEdge))
end do

do iCell = 1, nCellsNew
  r = sqrt( (xCellNew(iCell) - xmid)**2 + (yCellNew(iCell) - (ymid + 50.0 ))**2)
  if((yCellNew(iCell) > (ymid +50.0 ) .or. xCellNew(iCell) .ge. (xmid+5.0) .or. xCellNew(iCell) .le. (xmid-5.0)) .and. r < 25.0) then
     tracer1New(1,:,iCell) = 1.0
  end if
end do

! basin-mod
! set coriolis parameter for grid
write(6,*) ' setting Coriolis parameter'

fVertexNew = 0.0
fEdgeNew = 0.0

write(6,*) ' done not real bathymetry'
deallocate(psiVertex)

write(6,*) ' done get_init_conditions'


