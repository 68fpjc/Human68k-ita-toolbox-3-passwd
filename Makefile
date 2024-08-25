# Makefile for ITA TOOLBOX #3 PASSWD

MAKE = make

AS = HAS060
ASFLAGS = -m 68000 -i $(INCLUDE)
LD = hlk
LDFLAGS = -x
CV = -CV -r
CP = cp
RM = -rm -f

INCLUDE = ../01-fish/include

DESTDIR   = A:/bin
BACKUPDIR = B:/passwd/0.3
RELEASE_ARCHIVE = PASSWD03
RELEASE_FILES = MANIFEST README ../NOTICE CHANGES passwd.att passwd.ucb passwd.1 passwd.5

EXTLIB = ../01-fish/lib/ita.l

###

PROGRAM = passwd.att passwd.ucb

###

.PHONY : all clean clobber install release backup

.TERMINAL : *.h *.s

%.r : %.x
	$(CV) $<

%.x : %.o $(EXTLIB)
	$(LD) $(LDFLAGS) $^

%.o : %.s
	$(AS) $(ASFLAGS) $<

###

all:: $(PROGRAM)

clean::

clobber:: clean
	$(RM) *.bak *.$$* *.o *.x

###

$(PROGRAM:.x=.o) : $(INCLUDE)/doscall.h $(INCLUDE)/chrcode.h

$(EXTLIB) :
	cd $(@D); $(MAKE) $(@F)

include ../Makefile.sub

###

passwd.att : passwd.s
	$(AS) $(ASFLAGS) -s SYSV=1 -s BSD=0 $<
	$(LD) $(LDFLAGS) -o $@ $(<:.s=.o) $(EXTLIB)
	$(RM) $(<:.s=.o)

###

passwd.ucb : passwd.s
	$(AS) $(ASFLAGS) -s SYSV=0 -s BSD=1 $<
	$(LD) $(LDFLAGS) -o $@ $(<:.s=.o) $(EXTLIB)
	$(RM) $(<:.s=.o)

###
