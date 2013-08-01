implicit none
real :: halfwidth, dtr, pi, p(3), q(3), xin, yin, zin, ulon, ulat, stress, n1, n2, distance, r, temp_t, temp_s
real :: dotProd
real :: backgroundMaxTemp, backgroundMinTemp, bottomMinTemp
real :: y_a, y_0, A_0, beta, betaTemperature
real :: yTrans, vertTempChange, maxTemp
real, dimension(:), allocatable :: vertCoord
real, dimension(:,:,:), allocatable :: tempHolder
integer :: iTracer, ix, iy, ndata, i, j, k, ixt, iyt, ncull, jcount, iNoData, kdata(nVertLevelsMod)
logical :: flag_lat

pi = 4.0*atan(1.0)
dtr = pi/180.0

layerThicknessNew = 100.0
temperatureNew = 1.0
salinityNew = 1.0
tracer1New = 1.0
normalVelocityNew = 0

allocate(tempHolder(1, nVertLevelsMOD, nCellsNew))
allocate(vertCoord(nVertLevelsMOD))

write(6,*) ' not using real bathymetry'

fEdgeNew(:) = 0.0
fVertexNew(:) = 0.0
bottomDepthNew(:) = 0.0
normalVelocityNew(:,:,:) = 0.0

! basin-mod
! setting for three levels - Set h values for isopycnal system
write(6,*) ' setting three levels for isopycnal system'
vertCoord = 0.0
do i = 1, nVertLevelsMOD
    layerThicknessNew(1,i,:) = layer_thickness_total_max / nVertLevelsMOD
    hZLevel(i) =  layer_thickness_total_max / nVertLevelsMOD
    vertCoord(i) =  i * layer_thickness_total_max / nVertLevelsMOD
end do

bottomDepthNew(:) = layer_thickness_total_max

! basin-mod
!Specify Density values for isopycnal levels
write(6,*) ' setting density'
densityNew(1,:,:) = 1000.0

! basin-mod
! set temperature for isopycnal levels
write(6,*) ' setting temperature'
vertTempChange = 2.5
backgroundMaxTemp = 20.6
backgroundMinTemp = 9.5
do k = 1, nVertLevelsMOD
     temperatureNew(1,k,:) = (backgroundMaxTemp - backgroundMinTemp) * ((-vertCoord(k)+layer_thickness_total_max)/layer_thickness_total_max) + backgroundMinTemp
enddo

y_a = 50.0e3
y_0 = 125.0e3
A_0 = *AMP
do i = 1, nCellsNew
  if( abs(yCellNew(i) - y_0) < y_a) then
      do k = 1, nVertLevelsMOD
         betaTemperature = -A_0*cos(0.5*pi*(yCellNew(i)-y_0)/y_a)*sin(1.05*pi*vertCoord(k)/layer_thickness_total_max) 
         temperatureNew(1, k, i) = temperatureNew(1, k, i) + betaTemperature
      end do
  endif
enddo

! bottomMinTemp is set a little above backgroundMinTemp so gravity waves are not induced along the bottom
bottomMinTemp = 10.0
temperatureNew(1,:,:) = max(temperatureNew(1,:,:), bottomMinTemp)

! basin-mod
! set salinity for levels
salinityNew(1,:,:) = 35.0

! basin-mod
! set forcing for isopycnal levels
write(6,*) 'setting u_src - wind forcing'
normalVelocityNew = 0.0
write(6,*) ' normalVelocityNew ', minval(normalVelocityNew), maxval(normalVelocityNew)

! basin-mod
! set coriolis parameter for grid
write(6,*) ' setting Coriolis parameter'
ymid = (maxval(yVertexNew(:)) - minval(yVertexNew(:)))/2.0
do i = 1,nVerticesNew
  fVertexNew(i) = f0 + (yVertexNew(i) - ymid) * beta
enddo

ymid = (maxval(yEdgeNew(:)) - minval(yEdgeNew(:)))/2.0
do i = 1,nEdgesNew
  fEdgeNew(i) = f0 + (yEdgeNew(i) - ymid) * beta
enddo

write(6,*) ' done get_init_conditions'

deallocate(vertCoord)

