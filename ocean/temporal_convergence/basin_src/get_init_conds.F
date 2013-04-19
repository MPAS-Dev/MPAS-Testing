implicit none
real :: halfwidth, dtr, pi, p(3), q(3), xin, yin, zin, ulon, ulat, stress, n1, n2, distance, r, temp_t, temp_s
real :: dotProd
real :: surfMaxTemp, surfMinTemp
real :: y_0, x_0, x_1, x_2, x_3, width, cff1
real :: yTrans, vertTempChange, maxTemp
real, dimension(:), allocatable :: vertCoord
real, dimension(:,:,:), allocatable :: tempHolder
integer :: iTracer, ix, iy, ndata, i, j, k, ixt, iyt, ncull, jcount, iNoData, kdata(nVertLevelsMod)
logical :: flag_lat

pi = 4.0*atan(1.0)
dtr = pi/180.0

hNew = 100.0
temperatureNew = 1.0
salinityNew = 1.0
tracer1New = 1.0
uNew = 0

allocate(vertCoord(nVertLevelsMOD))
allocate(tempHolder(1, nVertLevelsMOD, nCellsNew))

fEdgeNew(:) = 0.0
fVertexNew(:) = 0.0
bottomDepthNew(:) = 0.0
uNew(:,:,:) = 0.0

! basin-mod
! setting for three levels - Set h values for isopycnal system
write(6,*) ' setting three levels for isopycnal system'
vertCoord = 0
do i = 1, nVertLevelsMOD
    hNew(1,i,:) = h_total_max / nVertLevelsMOD
    hZLevel(i) =  h_total_max / nVertLevelsMOD
    vertCoord(i) =  i * h_total_max / nVertLevelsMOD
end do

bottomDepthNew(:) = h_total_max

! basin-mod
!Specify Density values for isopycnal levels
write(6,*) ' setting density'
rhoNew(1,:,:) = 1000.0
if(nVertLevelsMOD .eq. 3) then
    rhoNew(1,2,:) = 1011.0
    rhoNew(1,3,:) = 1012.0
endif

! basin-mod
! set temperature for isopycnal levels
write(6,*) ' setting temperature'
vertTempChange = 2.5
surfMaxTemp = 13.1
surfMinTemp = 10.1
do k = 1, nVertLevelsMOD
     temperatureNew(1,k,:) = (surfMaxTemp - surfMinTemp) * ((-vertCoord(k)+h_total_max)/h_total_max)+ surfMinTemp
enddo

tempHolder = temperatureNew

y_0 = 200.0e3
x_0 = 0.0e3
x_1 = 160.0e3
x_2 = 110.0e3
x_3 = 130.0e3
width = 40.0e3
do i = 1, nCellsNew
  cff1 = width * sin (6.0 * 3.141592 * (xCellNew(i) - x_0)/(x_1 - x_0))

  if( yCellNew(i) < y_0 - cff1 ) then
      do k = 1, nVertLevelsMOD
         temperatureNew(1,k,i) = temperatureNew(1,k,i) - 1.2
      end do
  else if( yCellNew(i) .ge. y_0 - cff1 .and. yCellNew(i) .le. y_0 - cff1+width) then
      do k = 1, nVertLevelsMOD
         temperatureNew(1,k,i) = tempHolder(1,k,i) - 1.2*(1.0 -( yCellNew(i) - (y_0 - cff1)) / (1.0 * width))
      end do
  endif
enddo

do i = 1, nCellsNew
  cff1 = 0.5 * width * sin(1.0 * 3.141592 * (xCellNew(i) - x_2)/(x_3 - x_2))

  if( yCellNew(i) .ge. y_0 - cff1-0.5*width .and. yCellNew(i) .le. y_0 - cff1+0.5*width .and. xCellNew(i) .ge. x_2 .and. xCellNew(i) .le. x_3) then
    do k = 1, nVertLevelsMOD
      temperatureNew(1,k,i) = temperatureNew(1,k,i) + 0.3 * (1.0 - ( (yCellNew(i)-(y_0-cff1))/(0.5*width)))
    end do
  endif
end do

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

deallocate(tempHolder)
deallocate(vertCoord)
