implicit none
real :: halfwidth, dtr, pi, p(3), q(3), xin, yin, zin, ulon, ulat, stress, n1, n2, distance, r, temp_t, temp_s
real :: dotProd
real :: surfMaxTemp, surfMinTemp
real :: yTrans, vertTempChange, maxTemp
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

allocate(tempHolder(1, nVertLevelsMOD, nCellsNew))

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

write(6,*) ' adding noise to layer thickness'
r = 0.0
do i=1,nCellsNew
 work1(i) = float(i) / float(nCellsNew)
 call random_number(work1(i))
 r = r + work1(i)
enddo
r = r/float(nCells)
work1(:) = work1(:) - r


! basin-mod
! set temperature for isopycnal levels
write(6,*) ' setting temperature'
ymin = minval(yCellNew)
ymax = maxval(yCellNew)
ymid = (ymax+ymin)/2
! mrp 110712 for p37c, zlevel 25 layer.
do i = 1,nCellsNew
   ! tanh profile in y from Tmin=2 to Tmax=12, Tmid is 7.
   do k=1,3
      ! T = Tmid + (Tmax-Tmid)*tanh(c*(y-ymid)/(ymax-ymid))
      ! where c is a shape factor.
      temperatureNew(1,k,i) = 7.0 + 5.0*tanh(2*(yCellNew(i)-ymid)/(ymax-ymid))
   end do
   do k=4,nVertLevelsMod
      ! linear to bottom, set Tbot=3.5
      temperatureNew(1,k,i) = (3.5-temperatureNew(1,3,i))*(k-3)/(40-3) + temperatureNew(1,3,i)
   end do
end do

salinityNew(1,:,:) = 35.0

temperatureRestoreNew(:) = temperatureNew(1,1,:)
salinityRestoreNew(:) = salinityNew(1,1,:)

! basin-mod
! Specify Density values for isopycnal levels
! Linear EOS
write(6,*) ' setting density'
do i = 1,nCellsNew
  rhoNew(1,:,i) = 1000.0*(1.0 - 2.5e-4*temperatureNew(1,1,i) + 7.6e-4*salinityNew(1,1,i))
enddo

! basin-mod
! set forcing for isopycnal levels
write(6,*) 'setting u_src - wind forcing'
ymin = minval(yEdgeNew)
ymax = maxval(yEdgeNew)
r = 3.0e5
ymid = (ymax+ymin)/2
do i = 1,nEdgesNew
    ytmp = yEdgeNew(i)
    iCell1 = cellsOnEdgeNew(1,i)
    iCell2 = cellsOnEdgeNew(2,i)
    if(iCell1>0.and.iCell2>0) then
        pert =  u_src_max * exp(-(ytmp-ymid)**2/(r**2))
        write(8,*) ytmp,pert
        u_srcNew(1,i) = pert * normalsNew(1,i)
    endif
enddo

write(6,*) ' u_srcNew ', minval(u_srcNew), maxval(u_srcNew)

! basin-mod
! set coriolis parameter for grid
write(6,*) ' setting Coriolis parameter'
do i = 1,nVerticesNew
  fVertexNew(i) = f0 + (yVertexNew(i) - ymid) * beta
enddo

do i = 1,nEdgesNew
  fEdgeNew(i) = f0 + (yEdgeNew(i) - ymid) * beta
enddo

write(6,*) ' done not real bathymetry'

write(6,*) ' done get_init_conditions'

