	program fly
c
c       This program simulates the trajectories of molecules through a 
c       hexapole and Stark decelerator. A molecular packet with a definable
c       initial position and velocity spread is generated with a random
c       generator. 
c       
c       Last modification 23.01.07 by Bas van de Meerakker
c
c       Note: Changing dimensions of acceleration array must be done both in the 
c       main program AND in the subroutine F!!!
c
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c       Decleration of variables
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	IMPLICIT none
c
	character*128 dummychar ! used to cump some variables from the timeseq inputfile
        character*128 filename,filename1,filename2,arg ! required for the input of the timeseq and burstfile
        integer iarg,iargc,icm,indx ! used in the setup-part of the program
c       The following array is used for the decelerator-part of the potential:
        integer IXMAX,IYMAX,IZMAX
        PARAMETER(IXMAX=200,IYMAX=200,IZMAX=200)
       	real*8 accx(IXMAX,IYMAX,IZMAX)
        real*8 accy(IXMAX,IYMAX,IZMAX)
	real*8 accz(IXMAX,IYMAX,IZMAX)         
	real*8 gu		! gridunits
	integer ni,nj,nk
	integer nt,ntotal	! the number of stages
        integer nb,ne,nd	! beginning and end of the array that is used
	common /basis/ accx,accy,accz
	common /basis/  gu
        common /basis/ ni,nj,nk
	common /basis/ nt,ntotal
        common /basis/ nb,ne,nd
c
c
	real*8 trigBU
c
	real*8 x0,vx0,deltat,trig_offset,deltavx,fact,x_offset
	real*8 finalx,finaly,finalz,finaltof
	real*8 r,theta,vr,vtheta
	real*8 deltar,deltavr,delta_transverse, delta_long
	real*8 pseudoT
	real*8 mint,maxt
	real*8 minv,maxv
	real*8 dummy
	real*8 LA,LB,LC,L1,L2,L3,L4
c
	integer n,n_mol,outunit
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c       INTEGRATION PACKAGE
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        INTEGER NEQ,LRW,LIW
        PARAMETER (NEQ=6, LRW=33+7*NEQ, LIW=34)
        REAL*8 YSTART(NEQ)
        REAL*8 RWORK(LRW)
        INTEGER IWORK(LIW)
        REAL*8  TSTART,T,TEND, TWANT
        INTEGER INFO(15)
        INTEGER IDID
        REAL*8 RTOL, ATOL
        REAL*8 RPAR(10)
        INTEGER IPAR(10)
        EXTERNAL DDERKF
        EXTERNAL F, HEX, F2
	common /nico1/ TSTART,YSTART,TWANT,INFO,IDID,RWORK,RPAR,IPAR
c
c	REAL*8 random
c	EXTERNAL random
c	EXTERNAL random_package
c	EXTERNAL fake_distribution
	INTEGER*4 time
c
	integer i,ii,j,k,inunit, i_start
        common /stage/ i
	integer dummyi,dummyj,dummyk
	real*8  dummyx
c
	integer MAXTIMINGS
	PARAMETER(MAXTIMINGS=9000)	
	real*8 t2jump(MAXTIMINGS)
        integer m
	character*6 statusBU(MAXTIMINGS)
	common /christian/ t2jump,m,statusBU
c
	real*8 l_exc_dec,l_stage,W_stage,l_exc_det
	real*8 l_dec_det,l_sk_dec,r_sk,l_x0_sk,phase,l_nozzle_hex
        real*8 l_exc_hex, L_hex
	common /dimensions/ l_exc_dec, l_exc_hex, L_hex, W_stage
c
        real*8 mu,Vhex,Lambda,mass,r_hex,B
        common /hexapole/ Vhex,r_hex
        common /molecule/ mu,mass,Lambda,B
c
        real*8 deltatof 
        real*8 l_w,v,t_l
	integer tofoutput
	real*8 deltatof_slow
        real*8 deltatof_fast
c
	real*8 hexapole_begin
	real*8 hexapole_end
	real*8 decelerator_begin
	real*8 decelerator_end
	common /arraydimensions/ hexapole_begin,hexapole_end,
     .     decelerator_begin,decelerator_end
	real*8 tof,x,y,z,vx,vy,vz
	character*128 ptu	!query replace in potential_to_use
        character*8 hexapole
	character*8 pulse
	integer hit,p
        common /nico0/ tof,x,y,z,vx,vy,vz,
     .                 ptu,hit
        common /countlines/ p
	integer odd
	common /oddd/ odd   ! put in nico0
	EXTERNAL INTEGRATION
	EXTERNAL checkhit
c	
c
	integer load_integer
	real*8 load_real
	character*8 load_char
	character*128 load_longchar
	character*128 label
c
	integer maxlines_input
	integer pline
	character*8 packetfilename
	integer pin
	real*8  tin,xin,yin,zin,vxin,vyin,vzin
c
        real*8 Y0(6), YP(6)          !for the test
c
	call init_random_seed() 
c	
c	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c		SETUP
c	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        if (iargc().eq.0) then
	   write(*,*) 'Usage: fly_trap.exe -i1 "input timeseq file" '
	   write(*,*) '                    -i2 "input BURST file" '
	   stop
	else
          icm=0
          iarg = 0
          indx = iargc()
            do while (iarg .lt. indx)
	      iarg = iarg + 1 
	      call getarg(iarg,arg)
              if (arg .eq. '-i1') then
                iarg = iarg + 1
                call getarg(iarg,filename1)
              elseif (arg.eq. '-i2') then
                iarg = iarg + 1
                call getarg(iarg,filename2)
              end if
	   end do
      	end if
c
	write(*,*) ''
	write(*,*) 'READING Parameters from disc'
c
c reading parameters from the input file
c
        write(*,*) ''
	write(*,*) 'READING: ',filename1
c
	label='ni'              !Dimensions acceleration array
        ni=load_integer(label,filename1)
        label='nj'
        nj=load_integer(label,filename1)
        label='nk'
        nk=load_integer(label,filename1)
c Omit first and last data points; used only for fitting purposes:
	label='nbegin'
        nb=load_integer(label,filename1)
	label='neind'
        ne=load_integer(label,filename1)
	nd = ne-nb	
c Read dimensions
	label='gu'              !#gridunits/meter
        gu=load_integer(label,filename1)
c
	label='mu'		! dipole moment molecule in Debye
        mu=load_real(label,filename1)
	mu=mu*3.3356D-30	! mu in Cm
	label='Vhex'		! hexapole voltage in kV
        Vhex=load_real(label,filename1)
	Vhex=Vhex*1000D0	! Vhex in V
	label='Lambda'		! Lambda doublet splitting in GHz
        Lambda=load_real(label,filename1)
	label='r_hex'		! inner radius hexapole (m)
        r_hex=load_real(label,filename1)
	label='B'		! effective value of MK/J(J+1)
        B=load_real(label,filename1)
c
	label='r_sk'		!radius skimmer
        r_sk=load_real(label,filename1)
	label='LA'		!Distance center package to skimmer
	l_x0_sk=load_real(label,filename1)
	label='LB'		!Dist. skimmer-hexapole
        LB=load_real(label,filename1)
	l_nozzle_hex=l_x0_sk+LB
        l_exc_hex=l_x0_sk+LB
        LB = l_x0_sk + LB
c
	label='Hex'		!hexapole installed?
        hexapole=load_char(label,filename1)
	label='LC'		!hexapole (not used)
        LC=load_real(label,filename1)
	label='L1'		!hexapole (used)
        L1=load_real(label,filename1)
	L_hex = L1
	label='L2'               !hexapole (not used)
        L2=load_real(label,filename1)
	label='L3'		!hexapole-first stage
        L3=load_real(label,filename1)
c
	if(hexapole.eq.'yes') then
	   l_exc_dec  =  LB+LC+L1+L2+L3
	else
	   l_exc_dec = LB
	endif	 	
c
	l_stage = (nd/gu)	!Length of single stage
	W_stage=(nj-3)/(2*gu)	!Half the distance between opposing rods 
	label='L4'		!Distance decelerator to detection
        l_dec_det=load_real(label,filename1)
	label='nt'		!Number of stages (physical size)
        nt=load_integer(label,filename1)
        ntotal=nt
	l_exc_det=l_exc_dec+(nt*l_stage)+l_dec_det
c
        write(*,*) 'l_exc_dec:', l_exc_dec
        write(*,*) 'l_dec_det:', l_dec_det
        write(*,*) 'length of single stage:', l_stage
        write(*,*) 'number of stages (geometrical):', ntotal
	write(*,*) 'Distance to decelerator:',l_exc_dec
	write(*,*) 'Distance to detector:   ', l_exc_det
c
c       Parameters used in calculation
	label='mass'		!mass
        mass=load_real(label,filename1)
        mass = mass*1.6605402D-27 ! mass in kg
c
        label='n_mol'		!number of molecules flown
        n_mol=load_integer(label,filename1)	
	label='trigBU'		!trigger time difference diss. and burst unit
c				 time spent by molecule from the nozzle to the hexapole or decelerator
	trigBU=load_real(label,filename1)
        trigBU=trigBU/1.0e6
	label='packet'		!beam or block or packet pulse
        pulse=load_char(label,filename1)
c
	if (pulse.eq.'beam') then
	   label='r_nozl'	!extention in radial direction (mm)
	   deltar=load_real(label,filename1)
	   deltar = deltar*1D-3 !extention in radial direction (m)
	   label='w_prod'	!pulse width (mm)
           deltat=load_real(label,filename1)
	   deltat=deltat*1D-3	!pulse width (m)
	   label='mean_v'	!average velocity incoming package
	   vx0=load_real(label,filename1)
	   label='w_vlong'	!rel. velocity spread incoming package
	   deltavx=load_real(label,filename1)
	   deltavx=deltavx*vx0
	   label='w_vtrns'
	   deltavr=load_real(label,filename1)
	   deltavr=deltavr*vx0
	endif
	if (pulse.eq.'packet') then
	   label='pfile'	!file to load the packet
	   packetfilename=load_char(label,filename1)
	   write(*,*) packetfilename
	   label='pline'        !line to load 
           pline=load_integer(label,filename1)
	endif
c
	write(*,*) 'Vhex                  : ',Vhex
	write(*,*) 'mass                  : ',mass
	write(*,*) 'Lambda                : ',Lambda
	write(*,*) 'mu                    : ',mu
c
	write(*,*) 'l_exc_hex             : ',l_exc_hex
	write(*,*) 'L_hex                 : ',L_hex
c
	write(*,*) 'n_mol                 : ',n_mol
	write(*,*) '# stages used         : ',ntotal
	write(*,*) 'Pulse length (mm)     : ',deltat
	write(*,*) 'Ext. rad. dir.(m)     : ',deltar
	write(*,*) 'center vel. (m/s)     : ',vx0	
	write(*,*) 'vel. spread (m/s)     : ',deltavx
	write(*,*) 'lim. radial vel. (m/s): ',deltavr
c
c       x0      = 0
c	x0      = 0.10922		!x=0 at excitation region
c
c End reading parameters
c
c	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c		INPUT FILES 
c	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
c
        call read_T2jump(filename2,ntotal,trigBU
     .	 ,t2jump,m,statusBU)   !read in BURST file
	write(*,*) 'check T2jump parameters:',ntotal,trigBU,m
c	
	write(*,*) ''
c
c	DO i=283,286
c	write(*,*) 'check reading T2jump:',t2jump(i)
c	END DO
c
	write(*,*) ''
	write(*,*) 'READING acceleration files'
c
c	filename='../output/outax.dat'
	filename='../output/outax.dat'
	call read_acc(filename,accx,IXMAX,IYMAX,IZMAX,ni,nj,nk)
	filename='../output/outay.dat'
c	filename='../output/outay.dat'
	call read_acc(filename,accy,IXMAX,IYMAX,IZMAX,ni,nj,nk)
c	filename='../output/outaz.dat'
	filename='../output/outaz.dat'
	call read_acc(filename,accz,IXMAX,IYMAX,IZMAX,ni,nj,nk)
c
c
	write(*,*) 'INPUT FILES READ'
c
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c               OUTPUT FILES
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c 
	filename='../output/ff.dat'
	write(*,*) ''
	write(*,*) 'output written to ', filename
c
        outunit = 0
	open(unit = outunit,file = filename)
c
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c               INITIALISATION
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
c       Set begin and end of the different potential arrays
c       What counts here is where which array is used, not physical sizes
c       First the timings are checked, and only in the force where the molecules actually are.
c
	hexapole_begin = l_exc_hex
	hexapole_end = l_exc_hex + L_hex
	decelerator_begin = l_exc_dec
	decelerator_end = l_exc_dec+(nt*l_stage)
c
	write (*,*) 'check again distance to hexapole',
     .		hexapole_begin
	write (*,*) 'check again distance to hexapole end', 
     .		hexapole_end
	write (*,*) 'check again distance to decelerator', 
     .		decelerator_begin
	write (*,*) 'check again distance to decelerator end', 
     .		decelerator_end
c
c
	write(*,*) 'STARTING CALCULATION'
c
c
	if (pulse.eq.'packet') then
           inunit = 32
	   write(*,*) 'load from ',packetfilename
	   open(unit=inunit,file=packetfilename)
	   read(inunit,*) n_mol
	   read(inunit,*) maxlines_input
	endif

c
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c		START LOOP OVER MOLECULES 
c	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        do n=1,n_mol+2  !Loop for number of molecules to be flown
c                       +2 because the first 2 molecules are used to
c                       write n_mol and p (see below)
c
c
c
          if( mod(n,1000).eq.0) then   !screen output during run
	     write(*,*) 'done:',n
	  endif			
c
          if (n.eq.1) then   !(mis)use firt molecule to write this line
	     write(outunit,*) n_mol
	  endif
c	
          if (n.eq.2) then  !(mis)use second molecule to write p
	     write(outunit,*) p  !number of output lines per molecule
	  endif   
c
          p=0   !number of output lines per molecule
c
	  hit = 0		!four hits: 
				!hit=0: No problem
				!hit=1: Crash into electrodes
				!hit=2: Hit at end-aperture decelerator
				!hit=3: No entrance to decelerator
c
c Generate the molecules:
c	
        if(pulse.eq.'beam') then
	 x0 = 0
	 trig_offset = 0
	 call random_package(x0,deltat,trig_offset,deltar,vx0,deltavx,
     .                          deltavr,r_sk,l_x0_sk,W_stage,l_exc_dec)	    
	 else
	 if(pulse.eq.'block') then
	  x0 = x_offset
	  call fake_distribution(x0,delta_long,trig_offset,
     .	        delta_transverse,
     .	        vx0,deltavx,deltavr,r_sk,l_x0_sk,W_stage,l_exc_dec)
	  else 
	  if (pulse.eq.'packet') then
	   if ((n.eq.1).or.(n.gt.3)) then
	    pin=-1
	    do while(pin.ne.pline)
	     read(inunit,*) pin,tin,
     .          xin,yin,zin,vxin,vyin,vzin,hit
	    end do
	   endif
	   trig_offset=tin
	   x=xin
	   y=yin
	   z=zin
	   vx=vxin
           vy=vyin
           vz=vzin
	  endif
	 endif    
        endif
c
c end of generating molecules
c       
c       some initialization for integration routines
c	   do ii=1,15
c	      INFO(ii)=0
c	   enddo
	ATOL = 1D-6
	RTOL = 1D-6
c       
c	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c           START LOOP OVER SWITCH TIMES
c	XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
	tof=trig_offset        !if beam then this value is 0
	i=0
c	call writeoutput(n,0)
	do while(i.le.m)	!find first switch time for integration
	   if (t2jump(i).le.tof+1.e-9) then
	      i_start = i
c	        write(*,*) 'in', i_start, i,
c     .			t2jump(i),t2jump(1)
	   endif
	   i=i+1    
	enddo
c
	i = i_start	! now i from 0
c       write(*,*) 'iout', i
c       write(*,*) 'i_start', i_start
c
	if (pulse.eq.'packet') then
	   call writeoutput(n,pin)  
	else
	   call writeoutput(n,0)
	endif
c       
	do while((i.le.m-1))
c
c            write(*,*) '96' 
	     ptu='freeflight'  !assume free flight
	     if(statusBU(i).eq.'0x0001') then
		ptu='hexapole'
	     endif
	     if(statusBU(i).eq.'0x2000') then
		ptu='decelerator_vertical'
	     endif
             if(statusBU(i).eq.'0x1000') then
		ptu='decelerator_horizontal'
             endif
	     if(statusBU(i).eq.'0x0200') then
		ptu='decelerator_vertical'
	     endif
             if(statusBU(i).eq.'0x0100') then
		ptu='decelerator_horizontal'
             endif
c
	     if(statusBU(i).eq.'0x0A00') then
		ptu='decelerator_vertical'
	     endif
             if(statusBU(i).eq.'0x0500') then
		ptu='decelerator_horizontal'
             endif
c
	     if(statusBU(i).eq.'0x0800') then
		ptu='decelerator_vertical'
	     endif
             if(statusBU(i).eq.'0x0400') then
		ptu='decelerator_horizontal'
             endif
c
	     if(statusBU(i).eq.'0x0810') then
		ptu='decelerator_vertical'
	     endif
             if(statusBU(i).eq.'0x0420') then
		ptu='decelerator_horizontal'
             endif
c
	     if(statusBU(i).eq.'0x0010') then
		ptu='decelerator_vertical'
	     endif
             if(statusBU(i).eq.'0x0020') then
		ptu='decelerator_horizontal'
             endif
c
	     if(statusBU(i).eq.'0x0A10') then
		ptu='decelerator_vertical'
	     endif
             if(statusBU(i).eq.'0x0520') then
		ptu='decelerator_horizontal'
             endif
c
             if(statusBU(i).eq.'0x0000') then
		ptu='freeflight'
             endif
c
	      if(statusBU(i).eq.'0x0002') then
                ptu='decelerator_microwave'
             endif

c             write(*,*) '69'

c
c             write(*,*) 'switch ',i 
	     call integration(t2jump(i+1))
c	     TSTART,YSTART,TWANT,INFO,RTOL,ATOL,IDID,RWORK,RPAR,IPAR)  !integrate to next switch time
	     call checkhit()  !check for crash into electrodes
	     call check_min_max(vx,maxv,minv,finaltof,maxt,mint)     	  
c
c             if(i.ge.1) then  !write outputline at switch time i
c	       write(*,*) '2'
c	       call writeoutput(n,i) 
c	     endif  
c	     write(100,*) x,vx 
c	     write(101,*) y,vy 
c	     write(102,*) z,vz
c
             if(i.eq.1) then  !write outputline at switch time i (first stage)
	       call writeoutput(n,i)
	     endif 
c
c
             if(i.eq.(m-1)) then  !write outputline at switch time i (last stage)
	       call writeoutput(n,i)
	     endif 
c
	     i=i+1
c
	   end do   !End loop switching times
c
c           if(n.eq.1) then  !first molecule
c	      write(9999,*) n_mol
c           endif
c
       
	   call fly_to_detector(tof,W_stage,l_exc_det,decelerator_end,
     .                                            x,y,z,vx,vy,vz,hit) !needed for bin
c
	   call writeoutput(n,m+1) !write outputline (detector) 
c             write(*,*) 'end'
	end do	 !End loop number of molecules flown
c	
	close(outunit)
        close(tofoutput)
c
        minv=n_mol+2
c
	write(*,*) ''
	write(*,*) 'MIN Vx',minv
	write(*,*) 'MAX Vx',maxv
	write(*,*) ''
        write(*,*) ''
        write(*,*) 'total number of switching times:',m
        write(*,*) ''
c
        if((trigBU*vx0.lt.(l_nozzle_hex-0.001)).or.
     .      	(trigBU*vx0.gt.(l_nozzle_hex+0.001))) then
       	    write(*,*) 'WARNING: Incoupling time does not match!!!'
        endif
c
        write(*,*) ''
c
	if (pulse.eq.'packet') then
           close(inunit)
        endif
	write(*,*) 'out putlines:',p
c
1001	stop 'normal termination'
	end
c	
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         END OF PROGRAM                          XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
c
c
c
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         WRITE OUTPUT                            XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
	subroutine writeoutput(n,j)
	implicit none
	real*8 tof,x,y,z,vx,vy,vz
	character*128 ptu
        integer hit,p
        common /nico0/ tof,x,y,z,vx,vy,vz,
     .                 ptu,hit  
     	common /countlines/ p
c
	integer n
	integer j
	integer outunit
c
        outunit = 0

c       write output line in file ff.dat: 
c	(start generating output only after molecule #2:
c	use molecule #1 and #2 to count number of output lines 
c 	per molecule that is very helpful in the binning program)
c     

       	if(n.gt.2) then
	   write(outunit,*)j,tof,x,y,z,vx,vy,vz,hit
        endif
c
	p = p+1    !increase number of lines 
c
	return
	end
c
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         CHECK_HIT                               XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
c       This subroutine checks if the molecule crashes into 
c       electrodes. If so, it gets hit=1
c
        subroutine checkhit()
	IMPLICIT none
c
        real*8 tof,x,y,z,vx,vy,vz
        character*128 ptu
        integer hit
        common /nico0/ tof,x,y,z,vx,vy,vz,
     .                 ptu,hit
        integer odd
        common /oddd/ odd	
        real*8 mu,Vhex,Lambda,mass,r_hex,B
        common /hexapole/ Vhex,r_hex
        real*8 l_exc_dec,l_stage,W_stage,l_exc_det
        real*8 l_dec_det,l_sk_dec,r_sk,l_x0_sk,phase
        real*8 l_exc_hex, L_hex
        common /dimensions/ l_exc_dec, l_exc_hex, L_hex, W_stage
c
        real*8 hexapole_begin
        real*8 hexapole_end
        real*8 decelerator_begin
        real*8 decelerator_end
        common /arraydimensions/ hexapole_begin,hexapole_end,
     .     decelerator_begin,decelerator_end

c
c	hexapole
	if( (x.gt.hexapole_begin).and.(x.lt.hexapole_end)      
     .       .and.((y**2 + z**2).gt.r_hex**2)  ) then	  
	   hit = 1
	endif
c

c       decelerator 
	if( (x.gt.decelerator_begin)
     .      .and.(x.lt.decelerator_end)) then
	   if(   (abs(y).gt.(1.05*W_stage))
     .       .or.(abs(z).gt.(1.05*W_stage))) then
c	   if(   (abs(y).gt.(5e-3))
c     .       .or.(abs(z).gt.(5e-3))) then
	      hit = 1
	   endif
	endif

	return
	end
c

c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         INTEGRATION                             XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
c 	In this subroutine the real integration is done. 
c       Depending on the status of the BURST file, the routine
c       calls the correct Force subroutine to integrate.
c
        subroutine integration(t2reach)
c	TSTART,YSTART,TWANT,INFO,RTOL,	ATOL,IDID,RWORK,RPAR,IPAR)
	IMPLICIT none
c
	real*8 t2reach
c
	real*8 tof,x,y,z,vx,vy,vz
	character*128 ptu
        integer hit
        common /nico0/ tof,x,y,z,vx,vy,vz,
     .                 ptu,hit
        integer odd
        common /oddd/ odd
c
	integer i
	common /stage/ i	! nico0
c       integration variables
        INTEGER NEQ,LRW,LIW
        PARAMETER (NEQ=6, LRW=33+7*NEQ, LIW=34)
        REAL*8 YSTART(NEQ)
        REAL*8 RWORK(LRW)
        INTEGER IWORK(LIW)
        REAL*8  TSTART,T,TEND, TWANT
        INTEGER INFO(15)
        INTEGER IDID
        REAL*8 RTOL, ATOL
        REAL*8 RPAR(10)
        INTEGER IPAR(10)
        EXTERNAL DDERKF
        EXTERNAL F, HEX, F2
        common /nico1/ TSTART,YSTART,TWANT,INFO,IDID,RWORK,RPAR,IPAR
	real*8 temp
        ATOL = 1D-6
	RTOL = 1D-6
c
	TSTART = tof
        TWANT  = t2reach
c
	if((ptu.eq.'freeflight').and.(hit.eq.0)) then
           x = x + vx*(TWANT-TSTART)
           y = y + vy*(TWANT-TSTART)
           z = z + vz*(TWANT-TSTART)
	   tof = TWANT
        else                   ! end treatment freeflight
c

	YSTART(1) = x		!inital conditions for integration
	YSTART(2) = y
	YSTART(3) = z
	YSTART(4) = vx
	YSTART(5) = vy
	YSTART(6) = vz
c     
	if(ptu.eq.'decelerator_vertical') then
	   odd=1
	endif
	if((ptu.eq.'decelerator_horizontal')) then 
c       exchange y and z, i.e., rotate by 90\81\B0
	   temp = YSTART(2)
           YSTART(2) = YSTART(3)
           YSTART(3) = temp
           temp = YSTART(5)
           YSTART(5) = YSTART(6)
           YSTART(6) = temp
           odd=-1
	endif
c
	if((ptu.eq.'hexapole').and.(hit.eq.0)) then
	   call DDERKF(HEX, NEQ, TSTART, YSTART, TWANT, INFO,
     .   RTOL, ATOL, IDID, RWORK, LRW, IWORK, LIW, RPAR, IPAR)
	endif
	if(((ptu.eq.'decelerator_vertical')
     .  .or.(ptu.eq.'decelerator_horizontal')).and.(hit.eq.0)) then
	   call DDERKF(F, NEQ, TSTART, YSTART, TWANT, INFO,
     .   RTOL, ATOL, IDID, RWORK, LRW, IWORK, LIW, RPAR, IPAR)
	endif	 
c
c
	if(hit.eq.0) then  !increase tof only if molecule has not crashed
          tof = TWANT
	endif
c	  
        INFO(1)=0
c        if(IDID.ne.2) then
c          IDID=2 iff the integration went OK to the TEND
c           write(*,*) 'ERROR T in the ',ptu
c        endif
c
c       Return coordinates to main program
c
	x = YSTART(1)
	y = YSTART(2)
	z = YSTART(3)
	vx = YSTART(4)
	vy = YSTART(5)
	vz = YSTART(6)
c
        if(ptu.eq.'decelerator_horizontal') then 
c       reexchange x and z...
	   temp = y
           y = z
           z = temp
	   temp = vy
           vy = vz
           vz = temp
	endif
c
	endif			!not freeflight
	return
	end
c	
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         HEXAPOLE FORCE                          XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
	subroutine HEX(T, Y0, YP,RPAR,IPAR)
	IMPLICIT none
c	
	real*8 T, Y0(*), YP(*)		!YP = F(T, Y0)
c
	REAL*8 RPAR
	INTEGER IPAR
	real*8 Vhex, r_hex
	common /hexapole/ Vhex,r_hex
c
        real*8 hexapole_begin
        real*8 hexapole_end
        real*8 decelerator_begin
        real*8 decelerator_end
        common /arraydimensions/ hexapole_begin,hexapole_end,
     .     decelerator_begin,decelerator_end
	real*8 mu,mass,Lambda,B
	common /molecule/mu,mass,Lambda,B
c
        real*8 tof,x,y,z,vx,vy,vz
        character*128 ptu
        integer hit
        common /nico0/ tof,x,y,z,vx,vy,vz,
     .                 ptu,hit
c	
	real*8 enfrac
	real*8 k
	real*8 r
c
c
	k = (3.D0*mu*Vhex/r_hex**3)*B
	r = sqrt(Y0(2)*Y0(2) + Y0(3)*Y0(3))
	enfrac = (6.63D-34)*Lambda*1.0D9/k
c	
c       check position
	if (    (r.lt.r_hex)
     .     .and.(Y0(1).gt.hexapole_begin)
     .     .and.(Y0(1).lt.(hexapole_end))) then  
	   YP(4) = 0.0D0
	   YP(5) = -k/mass*(Y0(2))/sqrt(1 + (enfrac/(r**2))**2)
	   YP(6) = -k/mass*(Y0(3))/sqrt(1 + (enfrac/(r**2))**2) 
	else
	   YP(4) = 0.0D0
	   YP(5) = 0.0D0
	   YP(6) = 0.0D0
	endif	
c       
	YP(1) = Y0(4)
	YP(2) = Y0(5)
	YP(3) = Y0(6)	
c
	return
	end
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         DECELERATOR/BUNCHER FORCE               XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
	SUBROUTINE F(T,Y0,YP, RPAR, IPAR)
	IMPLICIT none
c	
	REAL*8 	T
	REAL*8  Y0(*),YP(*)
c	
        REAL*8 RPAR
        INTEGER IPAR
c
	REAL*8  YP1,YPN
c
        integer IXMAX,IYMAX,IZMAX
        PARAMETER(IXMAX=200,IYMAX=200,IZMAX=200)
        real*8 accx(IXMAX,IYMAX,IZMAX)
        real*8 accy(IXMAX,IYMAX,IZMAX)
        real*8 accz(IXMAX,IYMAX,IZMAX)
        real*8 gu
        integer ni,nj,nk
        common /basis/ accx,accy,accz
        common /basis/  gu
        common /basis/ ni,nj,nk
c
        integer nt,ntotal
        common /basis/ nt,ntotal
c
        integer nb,ne,nd
        common /basis/ nb,ne,nd
c
        real*8 xx,yy,zz
c
	real*8 g0i,g0j,g0k	
c
        integer i
        common /stage/ i	! put in nico0
c
	real*8 l_exc_dec, l_exc_hex, L_hex, W_stage
	common /dimensions/ l_exc_dec, l_exc_hex, L_hex, W_stage
c
	integer odd
        common /oddd/ odd
c
        integer xi,yj,zk,xit,xiactual
c
c       new variables
c
        real*8 tof,x,y,z,vx,vy,vz
        character*128 ptu
        integer hit
        common /nico0/ tof,x,y,z,vx,vy,vz,
     .                 ptu,hit
c
        real*8 hexapole_begin
        real*8 hexapole_end
        real*8 decelerator_begin
        real*8 decelerator_end
        common /arraydimensions/ hexapole_begin,hexapole_end,
     .     decelerator_begin,decelerator_end
c
c	write(*,*) T
c       check longitudinal position
	if((Y0(1).gt.decelerator_begin)
     .   .and.(Y0(1).lt.decelerator_end)) then
c
	g0i = -decelerator_begin
	g0j = dfloat(nj+1)/(2.*gu)
	g0k = dfloat(nk+1)/(2.*gu)
c
	xi = dint((Y0(1)+g0i)*gu) 
	yj = dint((Y0(2)+g0j)*gu)
	zk = dint((Y0(3)+g0k)*gu)
c
c
	if(((xi.ge.0).and.(xi.le.ntotal*nd)).and.
     .	   ((yj.ge.1).and.(yj.le.nj)).and.
     .	   ((zk.ge.1).and.(zk.le.nk)))   then
c

c
	  xx = (Y0(1)+g0i)*gu - dfloat(xi)
	  yy = (Y0(2)+g0j)*gu - dfloat(yj)
	  zz = (Y0(3)+g0k)*gu - dfloat(zk)
c
c	
	xiactual=xi  
c	  
	  if(odd.eq.-1) then
	    xi=xi+nd
  	  endif
c
        xit=xi
c 
	if (xiactual.le.nt*nd) ! molecule in decelerator spatially
c     .  .and.(i-3.le.nt) ) then  ! test in time crap!!!
     .  then
c
	  xi = mod(xit,(2*nd))   
          if(xi.lt.nd) then  
c
  	    xi = xi+nb
c
	YP(4)=((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*accx(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*accx(xi+1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*accx(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*accx(xi+1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *accx(xi,yj,zk+1) 
     .         +(xx)      *(1.0 - yy)*(zz)      *accx(xi+1,yj,zk+1) 
     .         +(1.0 - xx)*(yy)      *(zz)      *accx(xi,yj+1,zk+1) 
     .         +(xx)      *(yy)      *(zz)      *accx(xi+1,yj+1,zk+1))
c
	YP(5)=((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*accy(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*accy(xi+1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*accy(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*accy(xi+1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *accy(xi,yj,zk+1) 
     .         +(xx)      *(1.0 - yy)*(zz)      *accy(xi+1,yj,zk+1) 
     .         +(1.0 - xx)*(yy)      *(zz)      *accy(xi,yj+1,zk+1) 
     .         +(xx)      *(yy)      *(zz)      *accy(xi+1,yj+1,zk+1))
c
	YP(6)=((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*accz(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*accz(xi+1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*accz(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*accz(xi+1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *accz(xi,yj,zk+1) 
     .         +(xx)      *(1.0 - yy)*(zz)      *accz(xi+1,yj,zk+1) 
     .         +(1.0 - xx)*(yy)      *(zz)      *accz(xi,yj+1,zk+1) 
     .         +(xx)      *(yy)      *(zz)      *accz(xi+1,yj+1,zk+1))
c
c	write(*,*) 1,'  ',T,'  ',xi,'  ',YP(5)
c
          else ! if(xi.ge.nd) 
c
            xi = nb + (nd - (xi-nd)) !(2nd-xi)+nb
c
        YP(4)=-((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*accx(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*accx(xi-1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*accx(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*accx(xi-1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *accx(xi,yj,zk+1)
     .         +(xx)      *(1.0 - yy)*(zz)      *accx(xi-1,yj,zk+1)
     .         +(1.0 - xx)*(yy)      *(zz)      *accx(xi,yj+1,zk+1)
     .         +(xx)      *(yy)      *(zz)      *accx(xi-1,yj+1,zk+1))
c
        YP(5)=((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*accy(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*accy(xi-1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*accy(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*accy(xi-1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *accy(xi,yj,zk+1)
     .         +(xx)      *(1.0 - yy)*(zz)      *accy(xi-1,yj,zk+1)
     .         +(1.0 - xx)*(yy)      *(zz)      *accy(xi,yj+1,zk+1)
     .         +(xx)      *(yy)      *(zz)      *accy(xi-1,yj+1,zk+1))
c
        YP(6)=((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*accz(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*accz(xi-1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*accz(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*accz(xi-1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *accz(xi,yj,zk+1)
     .         +(xx)      *(1.0 - yy)*(zz)      *accz(xi-1,yj,zk+1)
     .         +(1.0 - xx)*(yy)      *(zz)      *accz(xi,yj+1,zk+1)
     .         +(xx)      *(yy)      *(zz)      *accz(xi-1,yj+1,zk+1))
c
c        write(*,*) 2,'  ',T,'  ',xi,'  ',YP(5) 
c
          endif ! xi.lt.nd test  
c
	else !test in time and position

         YP(4) = 0
         YP(5) = 0
         YP(6) = 0
c
	endif !test in time and position decelerator  
c
	else !big test on xi,yj,zk
c	  
	  YP(4) = 0
	  YP(5) = 0
	  YP(6) = 0
c
     	  if( (((yj.lt.1).or.(yj.gt.nj)).or.
     .	       ((zk.lt.1).or.(zk.gt.nk))).and.
     .         ((xi.le.ntotal*nd).and.(xi.ge.0)) )   then
c
	    hit = 1
c
	  endif
c
c	
	endif  !big test on xi,yj,zk
c		
	YP(1) = Y0(4)
	YP(2) = Y0(5)
	YP(3) = Y0(6)
c
c       end test molecule between decelerator_begin and buncher_end
	else
	   YP(1) = Y0(4)
	   YP(2) = Y0(5)
	   YP(3) = Y0(6)
	   YP(4) = 0D0
	   YP(5) = 0D0
	   YP(6) = 0D0
	endif
c
c        write(*,*) T,Y0(1),Y0(4),YP(4)	
c
	if(i.eq.2) then
c		write(100,*) Y0(1),YP(1)
c		write(101,*) Y0(2),YP(2)
c		write(102,*) Y0(3),YP(3)
	endif
	RETURN
	END
c
c
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         DECELERATOR/BUNCHER FORCE               XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        SUBROUTINE F2(T,Y0,YP, RPAR, IPAR)
        IMPLICIT none
c
        REAL*8  T
        REAL*8  Y0(*),YP(*)
c
        REAL*8 RPAR
        INTEGER IPAR
c
        REAL*8  YP1,YPN
c
        integer IXMAX,IYMAX,IZMAX
        PARAMETER(IXMAX=200,IYMAX=200,IZMAX=200)
        real*8 accxMW(IXMAX,IYMAX,IZMAX)
        real*8 accyMW(IXMAX,IYMAX,IZMAX)
        real*8 acczMW(IXMAX,IYMAX,IZMAX)
        real*8 guMW               ! gridunits
        integer niMW,njMW,nkMW
        integer ntMW,ntotalMW       ! the number of stages
        integer nbMW,neMW,ndMW        ! beginning and end of the array that is used
        common /basisMW/ accxMW,accyMW,acczMW
        common /basisMW/ guMW
        common /basisMW/ niMW,njMW,nkMW
        common /basisMW/ ntMW,ntotalMW
        common /basisMW/ nbMW,neMW,ndMW
c
        real*8 xx,yy,zz
c
        real*8 g0i,g0j,g0k
c
        integer i
        common /stage/ i        ! put in nico0
c
        real*8 l_exc_dec, l_exc_hex, L_hex, W_stage
        common /dimensions/ l_exc_dec, l_exc_hex, L_hex, W_stage
c
        integer odd
        common /oddd/ odd
c
        integer xi,yj,zk,xit,xiactual
c
c       new variables
c
        real*8 tof,x,y,z,vx,vy,vz
        character*128 ptu
        integer hit
        common /nico0/ tof,x,y,z,vx,vy,vz,
     .                 ptu,hit
c
        real*8 hexapole_begin
        real*8 hexapole_end
        real*8 decelerator_begin
        real*8 decelerator_end
        common /arraydimensions/ hexapole_begin,hexapole_end,
     .     decelerator_begin,decelerator_end
c
	real*8 deceleratorMW_begin
        real*8 deceleratorMW_end
c
c       manually entered 
	deceleratorMW_begin=decelerator_end+0.008
	deceleratorMW_end= deceleratorMW_begin+0.120
c       check longitudinal position

        if((Y0(1).gt.deceleratorMW_begin)
     .   .and.(Y0(1).lt.deceleratorMW_end)) then
c
        g0i = -deceleratorMW_begin
        g0j = dfloat(njMW+1)/(2.*guMW)
        g0k = dfloat(nkMW+1)/(2.*guMW)
c
        xi = dint((Y0(1)+g0i)*guMW)
        yj = dint((Y0(2)+g0j)*guMW)
        zk = dint((Y0(3)+g0k)*guMW)
c
c
        if(((xi.ge.0).and.(xi.le.ntotalMW*ndMW)).and.
     .     ((yj.ge.1).and.(yj.le.njMW)).and.
     .     ((zk.ge.1).and.(zk.le.nkMW)))   then
c

c
	xx = (Y0(1)+g0i)*guMW - dfloat(xi)
	yy = (Y0(2)+g0j)*guMW - dfloat(yj)
	zz = (Y0(3)+g0k)*guMW - dfloat(zk)
c
        xit=xi
	xi = mod(xit,ndMW)
	xi = xi+nbMW
c
        YP(4)=((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*accxMW(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*accxMW(xi+1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*accxMW(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*accxMW(xi+1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *accxMW(xi,yj,zk+1)
     .         +(xx)      *(1.0 - yy)*(zz)      *accxMW(xi+1,yj,zk+1)
     .         +(1.0 - xx)*(yy)      *(zz)      *accxMW(xi,yj+1,zk+1)
     .         +(xx)      *(yy)      *(zz)      *accxMW(xi+1,yj+1,zk+1))
c
        YP(5)=((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*accyMW(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*accyMW(xi+1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*accyMW(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*accyMW(xi+1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *accyMW(xi,yj,zk+1)
     .         +(xx)      *(1.0 - yy)*(zz)      *accyMW(xi+1,yj,zk+1)
     .         +(1.0 - xx)*(yy)      *(zz)      *accyMW(xi,yj+1,zk+1)
     .         +(xx)      *(yy)      *(zz)      *accyMW(xi+1,yj+1,zk+1))
c
        YP(6)=((1.0 - xx)*(1.0 - yy)*(1.0 - zz)*acczMW(xi,yj,zk)
     .         +(xx)      *(1.0 - yy)*(1.0 - zz)*acczMW(xi+1,yj,zk)
     .         +(1.0 - xx)*(yy)*      (1.0 - zz)*acczMW(xi,yj+1,zk)
     .         +(xx)      *(yy)*      (1.0 - zz)*acczMW(xi+1,yj+1,zk)
     .         +(1.0 - xx)*(1.0 - yy)*(zz)      *acczMW(xi,yj,zk+1)
     .         +(xx)      *(1.0 - yy)*(zz)      *acczMW(xi+1,yj,zk+1)
     .         +(1.0 - xx)*(yy)      *(zz)      *acczMW(xi,yj+1,zk+1)
     .         +(xx)      *(yy)      *(zz)      *acczMW(xi+1,yj+1,zk+1))
c
c        else !test in time and positioncccc
c
c        YP(4) = 0
c         YP(5) = 0
c         YP(6) = 0
c
c        endif !test in time and position decelerator
c
        else !big test on xi,yj,zk
c
          YP(4) = 0
          YP(5) = 0
          YP(6) = 0
c
          if( (((yj.lt.1).or.(yj.gt.njMW)).or.
     .         ((zk.lt.1).or.(zk.gt.nkMW))).and.
     .         ((xi.le.ntotalMW*ndMW).and.(xi.ge.0)) )   then
c
            hit = 1
c
          endif
c
c
        endif  !big test on xi,yj,zk
c
        YP(1) = Y0(4)
        YP(2) = Y0(5)
        YP(3) = Y0(6)
c
c       end test molecule between decelerator_begin and _end
        else
           YP(1) = Y0(4)
           YP(2) = Y0(5)
           YP(3) = Y0(6)
           YP(4) = 0D0
           YP(5) = 0D0
           YP(6) = 0D0
        endif
c
c        write(*,*) T,Y0(1),Y0(4),YP(4)
c
        if(i.eq.2) then
c               write(100,*) Y0(1),YP(1)
c               write(101,*) Y0(2),YP(2)
c               write(102,*) Y0(3),YP(3)
        endif
        RETURN
        END
c
c
c
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c              myrgauss
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        real*8 function myrgauss(xmean, sd)
        implicit none
c
        real*8 xmean,sd, r
        integer I
        call random_number(r)
        myrgauss = -6.0
        DO 10 I=1,12
          call random_number(r)
           myrgauss = myrgauss + r
 10     continue
        myrgauss = xmean + sd*myrgauss
        return
        end
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         RANDOM PACKAGE                          XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c 	Routine to generate a position and velocity distribution for a package
c 	of molecules. Gaussian along x direction (beam axis, width det. by deltat),
c 	block along y,z direction. Velocity: gaussian along x, block along y,z
c 	direction. vx, vy, vz, y and z are determined for a cross section of the beam 
c	at postion x0=0; if a molecule with these values can pass the skimmer, the 
c 	random time is determined, together with x, y, z for this timing. 
c
        subroutine random_package(x0,deltat,trig_offset,deltar,vx0,
     .             deltavx,deltavr,r_sk,
     .             l_x0_sk,W_stage,l_exc_dec)
        IMPLICIT none
c
	real*8 x0,deltat,trig_offset,deltar
	real*8 t,rad
	real*8 vx0,deltavx,deltavr,theta,vr,vtheta
	real*8 r_sk,l_x0_sk,W_stage,l_exc_dec
	real*8 d0,tan_phi,r_max,vr_max
	real*8 A,B,EPS,ETA
	real*8 V
	real*8 r
c
        real*8 tof,x,y,z,vx,vy,vz
        character*128 ptu
        integer hit
        common /nico0/ tof,x,y,z,vx,vy,vz,ptu,hit
c
c
c	  
	REAL*8 MYRGAUSS
c       
	x=0D0			! defaults to enter do-while loop
	vx=vx0
	y=1D60
	vy=0D0
	z=1D60
	vz=0D0
c
	do while(((y+vy*(l_x0_sk)/vx)**2+
     .   (z+vz*(l_x0_sk)/vx)**2).gt.(r_sk*r_sk))
c
c Only molecules passing through skimmer are used. 
c 
c "Gaussian" for vx:
c
	  vx = myrgauss(vx0,deltavx/2D0)   !HWHM should be used here
c "Block" for y,z:
          call random_number(r)
	  rad      = deltar      * sqrt(r)
          call random_number(r)
	  theta  = 2. *3.14159 *     (r)
	  y  = rad * sin(theta)
	  z  = rad * cos(theta)
c "Block" distribution for vy,vz!!
          call random_number(r)
	  vr      = deltavr * sqrt(r)
          call random_number(r)
	  vtheta  = 2.* 3.14159 *(r)
	  vy = vr * sin(vtheta)
	  vz = vr * cos(vtheta)
	end do
c
c"Gaussian" for t (and x):
c
c       t = myrgauss(trig_offset,deltat/2D0)
c	x=vx*t
c	y=y+vy*t
c	z=z+vz*t
c
c Fixed value for t: time of dissociation:
c
        t = trig_offset		!if beam then this value is 0
c
c "Gaussian" for x in dissociation:
c
	x = myrgauss(0D0,deltat/2D0)  !HWHM should be used
c
	return
	end	  
c
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXXXX     RANDOM PACKET; FAKE DITRIBUTION           XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        subroutine fake_distribution(x0,delta_long,trig_offset,
     .	       delta_transverse,
     .  	vx0,deltavx,deltavr,r_sk,
     .             l_x0_sk,W_stage,l_exc_dec)
        IMPLICIT none
c
	real*8 x0,delta_long,trig_offset,delta_transverse
	real*8 t,rad
	real*8 vx0,deltavx,deltavr,theta,vr,vtheta
	real*8 r_sk,l_x0_sk,W_stage,l_exc_dec
	real*8 d0,tan_phi,r_max,vr_max
	real*8 A,B,EPS,ETA
	real*8 V
	real*8 r
c
        real*8 tof,x,y,z,vx,vy,vz
        character*128 ptu
        integer hit
        common /nico0/ tof,x,y,z,vx,vy,vz,ptu,hit
c
	REAL*8 MYRGAUSS
c       
	x=0D0			! defaults to enter do-while loop
	vx=vx0
	y=1D60
	vy=0D0
	z=1D60
	vz=0D0
c 
c
c "Block" for x,y,z:
          call random_number(r)
          x  = x0 + delta_long*(r-0.5)
          call random_number(r)
	  y  = delta_transverse*(r-0.5)
          call random_number(r)
	  z  = delta_transverse*(r-0.5)
c
c "Block" distribution for vx,vy,vz
c
          call random_number(r)
          vx = vx0 + deltavx*(r-0.5)
          call random_number(r)
	  vy = deltavr*(r-0.5)
          call random_number(r)
	  vz = deltavr*(r-0.5)
c
c Fixed value for t
c
        tof = trig_offset
c


	return
	end	  




c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         READ ACCELERATION                       XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
	subroutine read_acc(filename,acceleration,IXM,IYM,IZM,
     .  ni,nj,nk)
	IMPLICIT none
c
c Reading acceleration file (x-z direction) from disc
c
	character*128 filename
	integer IXM,IYM,IZM
	real*8 acceleration(IXM,IYM,IZM)
	integer ni,nj,nk,inunit,i,j,k,dummyi,dummyj,dummyk
c	
	inunit = 11
	open(unit=inunit,file=filename)
	read(inunit,*) ni,nj,nk
	write(*,*) 'Dimensions array ',filename,ni,nj,nk
	do i=1,ni
	  do j=1,nj
	    do k=1,nk
	     read(inunit,*) dummyi,dummyj,dummyk,acceleration(i,j,k)
            end do
	  end do
	end do 
c
c
	close(inunit)
	return
	end
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         READ TIME TO JUMP                       XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
c	Read in the BURST file. The subroutine recognizes 
c       the format and length of the BURST file.
c
	subroutine read_T2jump(filename2,ntotal,trigBU
     .	 ,t2jump,m,statusBU)
	IMPLICIT none
	character*128 filename2
	integer ntotal,m
	integer dummyi,inunit
	integer MAXTIMINGS
        PARAMETER(MAXTIMINGS=9000)
	real*8 t2jump(MAXTIMINGS),trigBU
        character*6 statusBU(MAXTIMINGS)
c
	integer i,j,k,ii,aaa
	real*8 dump
	character*1 dumpc
	integer zero
c
	zero=ichar('0')
	inunit=1
	open(unit = inunit,file = filename2)
c
        j=0
        k=0
        dumpc='#'
        do while (dumpc.eq.'#')   !count number of lines
           read(inunit,*) dumpc
	   j=j+1
	   if(dumpc.eq.'[') then
	      k=j    !count number of comment lines
           endif
	enddo
	do while (dumpc.ne.'#')
	   read(inunit,*) dumpc
	   j=j+1
        enddo
        close(inunit)
c
	inunit=1
	open(unit = inunit,file = filename2)
c
	write(*,*) ''
	write(*,*) 'READING Switch-timesequence: ',filename2
c
        do i=1,k
	  read(inunit,*) dumpc
	enddo
c
        m = j-k-1  !number of lines containing switch times
	i=1
        do i=1,m   ! read in all switch times;
	   read(inunit,*) t2jump(i), statusBU(i)
	   t2jump(i) = ((t2jump(i)-1010)*1.0e-9)+trigBU  ! add incoupling time to all
c				switch times and correct for 1.01 mus		     
	enddo
c
        close(inunit)
c
	return
	end
c
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c XXX         CHECK MIN MAX                           XXX
c XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
c       This subroutine keeps track of the highest and lowest 
c       velocity etc. that has occured
c
	subroutine check_min_max(vx,maxv,minv,finaltof,maxt,mint)
	IMPLICIT none
c
	real*8 vx,maxv,minv
	real*8 finaltof,maxt,mint
c
	if(vx.gt.maxv) then
	  maxv = vx
	endif 
	if(vx.lt.minv) then
	  minv = vx
	endif  	
c
	if(finaltof.gt.maxt) then
	  maxt = finaltof
	endif 
	if(finaltof.lt.mint) then
	  mint = finaltof
	endif  
	return
	end
c

c      XXXXXXXXXXXXXXXXXXXXXXXXXX
c         Fly to detector
c      XXXXXXXXXXXXXXXXXXXXXXXXXXX
c
	subroutine fly_to_detector(tof,W_stage,l_exc_det,
     .                               decelerator_end,x,y,z,vx,vy,vz,hit)
	IMPLICIT none
	real*8 tof,W_stage,l_exc_det,decelerator_end
	real*8 x,y,z,vx,vy,vz
	integer hit
c       
        if (hit.eq.0) then
	  if (x.lt.decelerator_end) then
	     tof = tof + (decelerator_end-x)/vx   !fly to end decelerator first
	     y   = y   + vy*(decelerator_end-x)/vx
	     z   = z   + vz*(decelerator_end-x)/vx
	     x   = decelerator_end
             if ((abs(y).gt.W_stage).or.(abs(z).gt.W_stage)) then
	        hit = 1
	     endif	 
          endif             
          tof = tof +    (l_exc_det-x)/vx  ! fly to detector     
          y   = y   + vy*(l_exc_det-x)/vx
	  z   = z   + vz*(l_exc_det-x)/vx
	  x   = l_exc_det
	endif  

	return
	end
	

c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c               RANDOM
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
          SUBROUTINE init_random_seed()
            INTEGER :: i, n, clock
            INTEGER, DIMENSION(:), ALLOCATABLE :: seed
c
            CALL RANDOM_SEED(size = n)
            ALLOCATE(seed(n))
c
            CALL SYSTEM_CLOCK(COUNT=clock)

            seed = clock + 37 * (/ (i - 1, i = 1, n) /)
c to always get the same initial cloud
	    seed = 1
            CALL RANDOM_SEED(PUT = seed)

            DEALLOCATE(seed)
          END SUBROUTINE 
c
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c              load integer
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        integer function load_integer(label,filename)
        implicit none
c
	character*128 label
	character*128 filename
c
	character*128 dummych1,dummych2,dummych3
	integer dummyint
	integer inunit,dummycount,il
c
	inunit=34
        open(unit=inunit,file=filename)
	dummych2='aaaaa'
	dummycount=0
        do while((dummych2.ne.label).and.(dummych1.ne.'end-of-file'))
	   read(inunit,*) dummych1,dummych2,dummych3
	   dummycount=dummycount+1
	end do
	close(inunit)
        if (dummych2.ne.label) then 
	   write(*,*) 'not found ',label
	endif
	open(unit=inunit,file=filename)
	do il=1,dummycount-1
	   read(inunit,*) dummych1,dummych2,dummych3
	end do
	read(inunit,*) dummyint
	close(inunit)
	load_integer=dummyint
        return
        end
c
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c              load real
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        real*8 function load_real(label,filename)
        implicit none
c
        character*128 label
        character*128 filename
c
        character*128 dummych1,dummych2,dummych3
	real*8 dummyreal
        integer inunit,dummycount,il
c
        inunit=34
        open(unit=inunit,file=filename)
        dummych2='aaaaa'
        dummycount=0
        do while((dummych2.ne.label).and.(dummych1.ne.'end-of-file'))
           read(inunit,*) dummych1,dummych2,dummych3
           dummycount=dummycount+1
        end do
        close(inunit)
        if (dummych2.ne.label) then 
	   write(*,*) 'not found ',label
	endif
        open(unit=inunit,file=filename)
        do il=1,dummycount-1
           read(inunit,*) dummych1,dummych2,dummych3
        end do
        read(inunit,*) dummyreal
        close(inunit)
        load_real=dummyreal
        return
        end
c
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c              load char
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        character*8 function load_char(label,filename)
        implicit none
c
        character*128 label
        character*128 filename
c
        character*128 dummych1,dummych2,dummych3
	character*8 dummych
        integer inunit,dummycount,il	
c
        inunit=34
        open(unit=inunit,file=filename)
        dummych2='aaaaa'
        dummycount=0
        do while((dummych2.ne.label).and.(dummych1.ne.'end-of-file'))
           read(inunit,*) dummych1,dummych2,dummych3
           dummycount=dummycount+1
        end do
        close(inunit)
        if (dummych2.ne.label) then 
	   write(*,*) 'not found ',label
	endif
        open(unit=inunit,file=filename)
        do il=1,dummycount-1
           read(inunit,*) dummych1,dummych2,dummych3
        end do
        read(inunit,*) dummych
        close(inunit)
        load_char=dummych
        return
        end
c
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c              load char
c       XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
c
        character*8 function load_longchar(label,filename)
        implicit none
c
        character*128 label
        character*128 filename
c
        character*128 dummych1,dummych2,dummych3
        character*128 dummych
        integer inunit,dummycount,il
c
        inunit=34
        open(unit=inunit,file=filename)
        dummych2='aaaaa'
        dummycount=0
        do while((dummych2.ne.label).and.(dummych1.ne.'end-of-file'))
           read(inunit,*) dummych1,dummych2,dummych3
           dummycount=dummycount+1
        end do
        close(inunit)
        if (dummych2.ne.label) then 
	   write(*,*) 'not found ',label
	endif
        open(unit=inunit,file=filename)
        do il=1,dummycount-1
           read(inunit,*) dummych1,dummych2,dummych3
        end do
        read(inunit,*) dummych
        close(inunit)
        load_longchar=dummych
        return
        end
c
