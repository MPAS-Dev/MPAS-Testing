implicit none
real :: halfwidth, dtr, pi, p(3), q(3), xin, yin, zin, ulon, ulat, stress, n1, n2, distance, r, temp_t, temp_s
real :: dotProd
integer :: iTracer, ix, iy, ndata, i, j, k, ixt, iyt, ncull, jcount, iNoData, kdata(nVertLevelsMod)
logical :: flag_lat

pi = 4.0*atan(1.0)
dtr = pi/180.0

hNew = 100.0
temperatureNew = 1.0
salinityNew = 1.0
tracer1New = 1.0
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
    hZLevel(i) =  h_total_max / nVertLevelsMOD
end do

bottomDepthNew(:) = h_total_max

! basin-mod
!Specify Density values for isopycnal levels
write(6,*) ' setting density'
rhoNew(1,:,:) = 1000.0

! basin-mod
! set temperature for isopycnal levels
write(6,*) ' setting temperature'
k=1
do i = 1,nCellsNew
   if(yCellNew(i) < 27500) then
      temperatureNew(1,:,i) = 5.0
   else
      temperatureNew(1,:,i) = 35.0
   endif
enddo

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

fVertexNew = 0.0
fEdgeNew = 0.0

write(6,*) ' done get_init_conditions'

