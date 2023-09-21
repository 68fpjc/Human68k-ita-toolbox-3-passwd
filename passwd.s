* passwd - change login password
*
* Itagaki Fumihiko 25-Aug-91  Create.
* Itagaki Fumihiko 17-May-92  Add BSD style, and some bug fix.
*
* Usage: passwd [ name ]

.include doscall.h
.include chrcode.h
.include stat.h
.include limits.h
.include pwd.h
.include irandom.h

.xref DecodeHUPAIR

.if SYSV
.xref isalpha
.xref toupper
.xref stricmp
.xref reverse
.xref rotate
.else
.xref islower
.xref isupper
.endif

.xref iscntrl
.xref strlen
.xref strchr
.xref strcmp
.xref memcmp
.xref memset
.xref strcpy
.xref stpcpy
.xref init_irandom
.xref irandom
.xref cat_pathname
.xref getenv
.xref tfopen
.xref fclose
.xref remove
.xref fgetc
.xref fgets
.xref drvchkp
.xref getpass
.xref fgetpwnam
.xref crypt

PDB_argPtr	equ	$10
PDB_namePtr	equ	$b4


** �ϒ萔
MAXLOGNAME	equ	8
MAXPASSWD	equ	8

RANDOM_POOLSIZE	equ	61

STACKSIZE	equ	512

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0			*  HUPAIR�K���錾
.even
start1:
		movea.l	a0,a5				*  A5 := �v���O�����̃������Ǘ��|�C���^�̃A�h���X
		lea	bsstop(pc),a6			*  A6 := BSS�̐擪�A�h���X
		lea	stack_bottom(a6),a7		*  A7 := �X�^�b�N�̒�
		move.l	#-1,ptmp_fd(a6)
		sf	remove_ptmp(a6)
	*
	*  ���ϐ� SYSROOT �𓾂�
	*
		lea	str_nul(pc),a1
		lea	word_SYSROOT(pc),a0
		bsr	getenv
		beq	sysroot_ok

		movea.l	d0,a1
sysroot_ok:
		move.l	a1,sysroot(a6)
	*
	*  �W�����͂��[�����ǂ������`�F�b�N����
	*
		clr.l	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		lea	msg_not_a_tty(pc),a0
		btst	#7,d0				*  character=1/block=0
		beq	werror_leave_1
	*
	*  �������f�R�[�h����
	*
		lea	args_buffer(a6),a1		*  A1 := ��������i�[����G���A�̐擪�A�h���X
		lea	1(a2),a0			*  A0 := �R�}���h���C���̕�����̐擪�A�h���X
		bsr	strlen				*  D0.L �� A0 ������������̒��������߁C
		add.l	a1,d0				*    �i�[�G���A�̗e�ʂ�
		bcs	insufficient_memory

		cmp.l	8(a5),d0			*    �`�F�b�N����D
		bhs	insufficient_memory

		bsr	DecodeHUPAIR			*  �������f�R�[�h����D
	*
	*  �ύX���郆�[�U���𓾂�
	*
		move.l	a1,name(a6)
		tst.l	d0
		bne	name_ok

		lea	word_USER(pc),a0
		bsr	getenv
		bne	set_name

		lea	word_LOGNAME(pc),a0
		bsr	getenv
		bne	set_name
		*
		*  ���O�𕷂�
		*
		lea	msg_name(pc),a1
		lea	namebuf(a6),a0
		moveq	#8,d0
		bsr	getname
		bmi	leave_0

		move.l	a0,d0
set_name:
		move.l	d0,name(a6)
name_ok:
	*
	*  �p�X���[�h�E�t�@�C������A�ύX���郆�[�U����������
	*
		lea	path_passwd(pc),a2
		lea	passwd(a6),a0
		bsr	make_sys_pathname
		bmi	unknown_user

		moveq	#0,d0				*  �ǂݍ��݃��[�h
		bsr	tfopen
		bmi	unknown_user

		move.l	d0,d2
		lea	pwd_buf(a6),a0
		lea	pwd_line(a6),a1
		move.l	#PW_LINESIZE,d1
		movea.l	name(a6),a2
		bsr	fgetpwnam
		exg	d0,d2
		bsr	fclose
		tst.l	d2
		bne	unknown_user
	*
	*  �V�O�i���������[�`����ݒ肷��
	*
		pea	manage_interrupt_signal(pc)
		move.w	#_CTRLVC,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
		pea	manage_abort_signal(pc)
		move.w	#_ERRJVC,-(a7)
		DOS	_INTVCS
		addq.l	#6,a7
	*
	*  ptmp ��open����
	*
		lea	path_ptmp(pc),a2
		lea	ptmp(a6),a0
		bsr	make_sys_pathname		*  strlen(ptmp) < strlen(passwd) �Ȃ�A�G���[�ɂȂ锤���Ȃ�
		moveq	#0,d0
		bsr	tfopen
		bmi	create_tmp

		bsr	fclose
		lea	msg_tmpfile_busy(pc),a1
		bsr	werror2
		bra	leave_0

create_tmp:
		bsr	drvchkp
		move.w	#$20,-(a7)			*  �ʏ�̃t�@�C��
		move.l	a0,-(a7)
		DOS	_CREATE				*  ptmp���쐬����
		addq.l	#6,a7
		tst.l	d0
		bmi	cannot_write

		move.l	d0,ptmp_fd(a6)
		st	remove_ptmp(a6)
	*
	*  passwd ��open����
	*
		lea	passwd(a6),a0
		moveq	#0,d0
		bsr	tfopen
		lea	msg_cannot_read(pc),a1
		bmi	werror2_leave_1

		move.w	d0,passwd_fd(a6)
	*
	*  Changing ... ���b�Z�[�W��\��
	*
		lea	msg_user(pc),a0
		bsr	print
		movea.l	name(a6),a0
		bsr	print
		lea	msg_changing(pc),a0
		bsr	print
	*
	*  �i���^�j�V�p�X���[�h��q�˂�
	*
		bsr	getnewpasswd
		tst.l	d0
		bne	leave_0
	*
	*  �Vpasswd�t�@�C����ptmp�ɍ쐬����
	*
		bsr	copy
		bmi	cannot_write

		move.w	passwd_fd(a6),d0
		bsr	fclose
		move.l	ptmp_fd(a6),d0
		move.l	#-1,ptmp_fd(a6)
		bsr	fclose
		bmi	cannot_write
	*
	*  passwd �� passwd.??? �Ƀ��l�[������
	*
		lea	passwd(a6),a1
		move.w	#-1,-(a7)
		move.l	a1,-(a7)
		DOS	_CHMOD
		addq.l	#6,a7
		move.l	d0,d7				*  D7 : passwd �� mode
		bmi	could_not_rename_passwd

		bclr	#0,d0				*  �X�V��������
		move.w	d0,-(a7)
		move.l	a1,-(a7)
		DOS	_CHMOD
		addq.l	#6,a7
		tst.l	d0
		bmi	could_not_rename_passwd

		lea	opasswd(a6),a0
		move.l	a0,-(a7)
		move.l	a1,-(a7)
		bsr	stpcpy
		lea	dot_000(pc),a1
		bsr	strcpy
opasswd_loop:
		DOS	_RENAME
		tst.l	d0
		bpl	opasswd_ok

		lea	4(a0),a1
opasswd_inc:
		cmpi.b	#'.',-(a1)
		beq	could_not_rename_passwd

		add.b	#1,(a1)
		cmpi.b	#'9',(a1)
		bls	opasswd_loop

		move.b	#'0',(a1)
		bra	opasswd_inc

could_not_rename_passwd:
		addq.l	#8,a7
		bra	leave_1

opasswd_ok:
		addq.l	#8,a7
	*
	*  ptmp �� passwd �Ƀ��l�[������
	*
		pea	passwd(a6)
		pea	ptmp(a6)
		DOS	_RENAME
		addq.l	#8,a7
		bset	#MODEBIT_RDO,d7			*  READ ONLY
		move.w	d7,-(a7)
		pea	passwd(a6)
		DOS	_CHMOD
		addq.l	#6,a7
	*
	*  passwd.??? ���폜����
	*
		lea	opasswd(a6),a0
		bsr	remove
	*
	*  �I��
	*
leave_0:
		moveq	#0,d0
leave:
		move.w	d0,-(a7)
		bsr	clear_password_buffers
		move.l	ptmp_fd(a6),d0
		bmi	leavex1

		bsr	fclose
leavex1:
		tst.b	remove_ptmp(a6)
		beq	exit

		lea	ptmp(a6),a0
		bsr	remove
exit:
		DOS	_EXIT2
****************
cannot_write:
		lea	ptmp(a6),a0
		lea	msg_cannot_write(pc),a1
werror2_leave_1:
		bsr	werror2
leave_1:
		moveq	#1,d0
		bra	leave
****************
unknown_user:
		movea.l	name(a6),a0
		lea	msg_unknown_user(pc),a1
		bra	werror2_leave_1
*****************************************************************
manage_abort_signal:
		move.w	#$3fc,d0		* D0 = 03FC
		cmp.w	#$100,d1
		bcs	manage_signals

		addq.w	#1,d0			* D0 = 03FD
		cmp.w	#$200,d1
		bcs	manage_signals

		addq.w	#2,d0			* D0 = 03FF
		cmp.w	#$ff00,d1
		bcc	manage_signals

		cmp.w	#$f000,d1
		bcc	manage_signals

		move.b	d1,d0
		bra	manage_signals

manage_interrupt_signal:
		move.w	#$200,d0		* D0 = 00000200
manage_signals:
		lea	bsstop(pc),a6			*  A6 := BSS�̐擪�A�h���X
		lea	stack_bottom(a6),a7		*  A7 := �X�^�b�N�̒�
		bra	leave
****************************************************************
* getname - �W�����͂���G�R�[�t����1�s���͂���iCR�܂���LF�܂Łj
*
* CALL
*      A0     ���̓o�b�t�@
*      A1     �v�����v�g������
*      D0.L   �ő���̓o�C�g���iCR��LF�͊܂܂Ȃ��j
*
* RETURN
*      D0.L   ���͕������iCR��LF�͊܂܂Ȃ��j
*             ������ EOF �Ȃ� -1
*      CCR    TST.L D0
****************************************************************
getname:
		movem.l	d1-d2/a0-a2,-(a7)
		move.l	d0,d2
getname_restart:
		exg	a0,a1
		bsr	print
		exg	a0,a1
		moveq	#0,d1
		movea.l	a0,a2
getname_loop:
		DOS	_INKEY
		tst.l	d0
		bmi	getname_eof

		cmp.b	#EOT,d0
		beq	getname_eof

		cmp.b	#$04,d0				*  $04 == ^D : EOF
		beq	getname_eof

		cmp.b	#CR,d0
		beq	getname_done

		cmp.b	#LF,d0
		beq	getname_done

		move.w	d0,-(a7)
		move.w	d0,-(a7)
		bsr	iscntrl
		bne	getname_echo

		add.b	#$40,d0
		and.b	#$7f,d0
		move.w	d0,(a7)
		moveq	#'^',d0
		bsr	putchar
getname_echo:
		move.w	(a7)+,d0
		bsr	putchar
		move.w	(a7)+,d0

		cmp.b	#$03,d0				*  $03 == ^C : Interrupt
		beq	getname_interrupt

		cmp.b	#$15,d0				*  $15 == ^U : Kill
		beq	getname_cancel

		cmp.l	d2,d1
		bhs	getname_loop

		move.b	d0,(a2)+
		addq.l	#1,d1
		bra	getname_loop

getname_cancel:
		bsr	put_newline
		bra	getname_restart

getname_interrupt:
		bsr	put_newline
getname_eof:
		moveq	#-1,d0
		bra	getname_return

getname_done:
		clr.b	(a2)
		bsr	put_newline
		move.l	d1,d0
getname_return:
		movem.l	(a7)+,d1-d2/a0-a2
		rts
****************************************************************
getnewpasswd:
		bsr	clear_password_buffers
		movea.l	pwd_buf+PW_PASSWD(a6),a0
		tst.b	(a0)				*  �p�X���[�h���ݒ肳��Ă��Ȃ����
		beq	check_period			*  ���݂̃p�X���[�h�͕����Ȃ�

		cmpi.b	#',',(a0)
		beq	check_period
	*
	*  ���s�̃p�X���[�h��q�˂ďƍ�����
	*
		lea	msg_old_password(pc),a1
		lea	old_password(a6),a0
		move.l	#MAXPASSWD,d0
		bsr	getpassx
		movea.l	pwd_buf+PW_PASSWD(a6),a1
		lea	crypt_buf(a6),a2
		bsr	crypt
		movea.l	a2,a0
		moveq	#13,d0
		bsr	memcmp
		beq	ask_new_password

		lea	msg_sorry(pc),a0
		bra	unchanged
	*
	*  �p�X���[�h�̕ύX�֎~���Ԃ��`�F�b�N����
	*
check_period:
	*
	*  �V�p�X���[�h�𕷂�
	*
ask_new_password:
		move.b	#3,failures_count(a6)
		move.b	#3,tries_count(a6)
ask_new_password_loop:
		lea	msg_new_password(pc),a1
		lea	new_password(a6),a0
		move.l	#MAXPASSWD,d0
		bsr	getpassx
		move.l	d0,d1				*  D1.L : �p�X���[�h�̒���
.if SYSV
*
*  System-V �n�̐R��
*
		*
		*  6�����ȏ゠�邩�H
		*
		lea	msg_sysv_too_short(pc),a2
		cmp.l	#6,d1
		blo	failure

		lea	new_password(a6),a0
		moveq	#0,d2				*  alphabetic counter
		moveq	#0,d3				*  non-alphabetic counter
passwd_count_loop:
		move.b	(a0)+,d0
		beq	passwd_count_done

		bsr	isalpha
		beq	inc_alpha

		addq.l	#1,d3
		bra	passwd_count_loop

inc_alpha:
		addq.l	#1,d2
		bra	passwd_count_loop

passwd_count_done:
		*
		*  �A���t�@�x�b�g�� 2�����ȏ゠�邩�H
		*
		lea	msg_too_few_alpha(pc),a2
		cmp.l	#2,d2
		blo	failure
		*
		*  ��A���t�@�x�b�g�� 1�����ȏ゠�邩�H
		*
		lea	msg_no_special(pc),a2
		tst.l	d3
		beq	failure
		*
		*  ���O�C������A���̉�]�ł͂Ȃ����H
		*
		lea	msg_same_to_logname(pc),a2
		movea.l	pwd_buf+PW_NAME(a6),a1
		lea	password_buf(a6),a0
		bsr	strcpy
		bsr	compare_with_logname
		beq	failure
		*
		*  ���O�C�����̔��]��A���̉�]�ł͂Ȃ����H
		*
		lea	password_buf(a6),a0
		lea	(a0,d1.l),a1
		bsr	reverse
		bsr	compare_with_logname
		beq	failure
		*
		*  ����܂ł̃p�X���[�h�Ƃ̈Ⴂ�� 3�����ȏ゠�邩
		*
		lea	new_password(a6),a0
		lea	old_password(a6),a1
		moveq	#2,d2
compare_loop:
		move.b	(a0),d0
		beq	compare_1

		addq.l	#1,a0
		bsr	toupper
compare_1:
		move.b	d0,d1
		move.b	(a1),d0
		beq	compare_2

		addq.l	#1,a1
		bsr	toupper
compare_2:
		cmp.b	d0,d1
		bne	compare_dec

		tst.b	d0
		bne	compare_loop

		lea	msg_too_few_diff(pc),a2
		bra	failure

compare_dec:
		dbra	d2,compare_loop
.else
*
*  BSD �n�̐R��
*
		*tst.l	d1
		lea	msg_password_unchanged(pc),a0
		beq	unchanged

		lea	new_password(a6),a0
		st	d2				*  only upper flag
		st	d3				*  only lower flag
passwd_count_loop:
		move.b	(a0)+,d0
		beq	passwd_count_done

		bsr	islower
		beq	clear_only_upper_flag

		bsr	isupper
		beq	clear_only_lower_flag

		sf	d3
clear_only_upper_flag:
		sf	d2
		bra	passwd_count_loop

clear_only_lower_flag:
		sf	d3
		bra	passwd_count_loop

passwd_count_done:
		*
		*  �啶���݂̂��������݂̂̏ꍇ�� 6�����ȏ�
		*  ����ȊO�̏ꍇ�� 4�����ȏ゠�邩�ǂ������`�F�b�N����
		*
		moveq	#6,d0
		tst.b	d2
		bne	check_password_length

		tst.b	d3
		bne	check_password_length

		moveq	#4,d0
check_password_length:
		lea	msg_bsd_too_short(pc),a2
		cmp.l	d0,d1
		blo	failure
.endif
recognize:
		*
		*  ������x�����ďƍ�����
		*
		lea	msg_retype(pc),a1
		lea	password_buf(a6),a0
		move.l	#MAXPASSWD,d0
		bsr	getpassx
		lea	new_password(a6),a1
		bsr	strcmp
		bne	mismatch
		*
		*  �Í�������
		*
		DOS	_GETTIM2
		moveq	#RANDOM_POOLSIZE,d1
		lea	irandom_struct(a6),a0
		bsr	init_irandom
		lea	salt(a6),a1
		bsr	irandom
		lea	itoa64(pc),a0
		move.b	d0,d1
		and.l	#$3f,d1
		move.b	(a0,d1.l),d1
		move.b	d1,(a1)
		lsr.l	#6,d0
		and.l	#$3f,d0
		move.b	(a0,d0.l),d0
		move.b	d0,1(a1)
		clr.b	2(a1)
		lea	new_password(a6),a0
		lea	crypt_buf(a6),a2
		bsr	crypt
		bsr	clear_password_buffers
		moveq	#0,d0
		rts


failure:
.if SYSV
		movea.l	a2,a0
		bsr	print
		sub.b	#1,failures_count(a6)
		bne	ask_new_password_loop

		lea	msg_too_many_failure(pc),a0
		bra	unchanged
.else
		sub.b	#1,failures_count(a6)
		beq	recognize			*  BSD�n�͐܂��

		movea.l	a2,a0
		bsr	print
		bra	ask_new_password_loop
.endif

mismatch:
.if SYSV
		lea	msg_sysv_mismatch(pc),a0
		bsr	print
		sub.b	#1,tries_count(a6)
		bne	ask_new_password_loop

		lea	msg_too_many_tries(pc),a0
.else
		lea	msg_bsd_mismatch(pc),a0
.endif
unchanged:
		bsr	print
		bsr	clear_password_buffers
		moveq	#1,d0
		rts
****************
.if SYSV

compare_with_logname:
		movem.l	d2/a0-a2,-(a7)
		move.w	d1,d2
		subq.w	#1,d2
compare_with_logname_loop:
		lea	new_password(a6),a1
		lea	password_buf(a6),a0
		bsr	stricmp
		beq	compare_with_logname_return

		lea	1(a0),a1
		lea	(a0,d1.l),a2
		bsr	rotate
		dbra	d2,compare_with_logname_loop

		moveq	#1,d0
compare_with_logname_return:
		movem.l	(a7)+,d2/a0-a2
		rts

.endif
*****************************************************************
getpassx:
		bsr	getpass
		movem.l	d0/a0,-(a7)
		lea	str_newline(pc),a0
		bsr	werror
		movem.l	(a7)+,d0/a0
		tst.l	d0
		rts
****************************************************************
copy:
		movea.l	name(a6),a0
		bsr	strlen
		move.l	d0,d2				*  D2.L : name �̒���
		sf	d3				*  D3.B : done
copy_loop:
		lea	pwd_line(a6),a0
		move.w	passwd_fd(a6),d0
		move.l	#PW_LINESIZE,d1
		bsr	fgets
		bmi	copy_last
		bne	copy_more

		tst.b	d3
		bne	copy_line

		lea	pwd_line(a6),a0
		movea.l	name(a6),a1
		move.l	d2,d0
		bsr	memcmp
		bne	copy_line

		moveq	#';',d0
		cmp.b	(a0,d2.l),d0
		bne	copy_line

		lea	1(a0,d2.l),a0		*  A0 : top of passwd
		movea.l	a0,a1			*  A1 : top of passwd
		bsr	strchr			*  ; �̓V�t�gJIS�̑��o�C�g�ɂ͖���
		beq	copy_line
						*  A0 : bottom of passwd
		movea.l	a0,a2			*  A2 : bottom of passwd
		addq.l	#1,a0			*  A0 : top of uid
		bsr	strchr			*  ; �̓V�t�gJIS�̑��o�C�g�ɂ͖���
		beq	copy_line
						*  A0 : bottom of uid
		addq.l	#1,a0			*  A0 : top of gid
		bsr	strchr			*  ; �̓V�t�gJIS�̑��o�C�g�ɂ͖���
		beq	copy_line
						*  A0 : bottom of gid
		addq.l	#1,a0			*  A0 : top of gecos
		bsr	strchr			*  ; �̓V�t�gJIS�̑��o�C�g�ɂ͖���
		beq	copy_line
						*  A0 : bottom of gecos
		addq.l	#1,a0			*  A0 : top of dir
		bsr	strchr			*  ; �̓V�t�gJIS�̑��o�C�g�ɂ͖���
		beq	copy_line
						*  A0 : bottom of dir
		st	d3

		move.l	a1,d0
		lea	pwd_line(a6),a0
		sub.l	a0,d0
		bsr	write_region
		bmi	copy_return

		lea	crypt_buf(a6),a0
		bsr	write_string
		bmi	copy_return

		movea.l	a2,a0
		bra	copy_line_1

copy_more:
		lea	pwd_line(a6),a0
		bsr	write_string
		bmi	copy_return

		move.w	passwd_fd(a6),d0
		move.l	#PW_LINESIZE,d1
		bsr	fgets
		bmi	copy_last
		bne	copy_more
copy_line:
		lea	pwd_line(a6),a0
copy_line_1:
		bsr	write_string
		bmi	copy_return

		lea	str_newline(pc),a0
		bsr	write_string
		bpl	copy_loop
copy_return:
		rts


copy_last:
		lea	pwd_line(a6),a0
write_string:
		bsr	strlen
write_region:
		move.l	d1,-(a7)
		move.l	d0,d1
		beq	write_region_return

		move.l	d0,-(a7)
		move.l	a0,-(a7)
		move.l	ptmp_fd(a6),d0
		move.w	d0,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	write_region_return

		cmp.l	d1,d0
		beq	write_region_return

		moveq	#-23,d0
write_region_return:
		move.l	(a7)+,d1
		tst.l	d0
		rts
****************************************************************
clear_password_buffers:
		lea	old_password(a6),a0
		bsr	clear_1_password_buffer
		lea	new_password(a6),a0
		bsr	clear_1_password_buffer
		lea	password_buf(a6),a0
clear_1_password_buffer:
		move.l	#MAXPASSWD+1,d1
		moveq	#0,d0
		bra	memset
****************************************************************
insufficient_memory:
		lea	msg_insufficient_memory(pc),a0
werror_leave_1:
		bsr	werror
		bra	leave_1
*****************************************************************
make_sys_pathname:
		movea.l	sysroot(a6),a1
		bra	cat_pathname
*****************************************************************
putchar:
		move.w	d0,-(a7)
		DOS	_PUTCHAR
		addq.l	#2,a7
		rts
*****************************************************************
put_newline:
		pea	str_newline(pc)
		DOS	_PRINT
		addq.l	#4,a7
		rts
*****************************************************************
print:
		move.l	a0,-(a7)
		DOS	_PRINT
		addq.l	#4,a7
		rts
*****************************************************************
werror2:
		move.l	a0,-(a7)
		lea	msg_passwd_colon(pc),a0
		bsr	werror
		movea.l	(a7),a0
		bsr	werror
		lea	msg_colon(pc),a0
		bsr	werror
		movea.l	a1,a0
		bsr	werror
		movea.l	(a7)+,a0
		rts
*****************************************************************
werror:
		move.l	a1,-(a7)
		movea.l	a0,a1
werror_count:
		tst.b	(a1)+
		bne	werror_count

		subq.l	#1,a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movea.l	(a7)+,a1
		rts
*****************************************************************
.data

	dc.b	0
.if SYSV
	dc.b	'## passwd.att 0.2 ##  Copyright(C)1992 by Itagaki Fumihiko',0
.else
	dc.b	'## passwd.ucb 0.2 ##  Copyright(C)1992 by Itagaki Fumihiko',0
.endif

word_LOGNAME:			dc.b	'LOGNAME',0
word_USER:			dc.b	'USER',0
word_SYSROOT:			dc.b	'SYSROOT',0
msg_not_a_tty:			dc.b	'passwd: ���͂��L�����N�^�E�f�o�C�X�ł���܂���',CR,LF,0
msg_insufficient_memory:	dc.b	'passwd: ������������܂���',CR,LF,0
msg_unknown_user:		dc.b	'���̂悤�ȃ��[�U�͓o�^����Ă��܂���',CR,LF,0
msg_tmpfile_busy:		dc.b	'�ꎞ�t�@�C�����g���Ă��܂�',CR,LF,0
msg_cannot_read:		dc.b	'�ǂݍ��߂܂���',CR,LF,0
msg_cannot_write:		dc.b	'�������߂܂���',CR,LF,0
msg_user:			dc.b	'���[�U ',0
msg_changing:			dc.b	' �̃p�X���[�h��ύX���܂��B'
str_newline:			dc.b	CR,LF,0
msg_passwd_colon:		dc.b	'passwd'
msg_colon:			dc.b	': ',0
msg_name:			dc.b	'���[�U��: ',0
msg_old_password:		dc.b	'���p�X���[�h:',0
msg_new_password:		dc.b	'�V�p�X���[�h:',0
msg_retype:			dc.b	'�V�p�X���[�h��������x���͂��Ă�������:',0
msg_sorry:			dc.b	'�����ɂ��ł����B',CR,LF,0
.if SYSV
msg_sysv_too_short:		dc.b	'�p�X���[�h���Z�����܂��B�����Ƃ��U���Ȃ���΂Ȃ�܂���B',CR,LF,0
msg_too_few_alpha:		dc.b	'�p�X���[�h�ɂ̓A���t�@�x�b�g�����������Ƃ��Q�܂܂�Ȃ���΂Ȃ�܂���B',CR,LF,0
msg_no_special:			dc.b	'�p�X���[�h�ɂ̓A���t�@�x�b�g�ȊO�̕����������Ƃ��P�܂܂�Ȃ���΂Ȃ�܂���B',CR,LF,0
msg_same_to_logname:		dc.b	'�p�X���[�h�̓��O�C�����₻��𔽓]���邢�͉�]�������̂ł����Ă͂Ȃ�܂���B',CR,LF,0
msg_too_few_diff:		dc.b	'�V�p�X���[�h�͏����Ƃ��R�ӏ��̕��������p�X���[�h�ƈ���Ă��Ȃ���΂Ȃ�܂���B',CR,LF,0
msg_sysv_mismatch:		dc.b	'���v���Ă��܂���B������x����蒼�����������B',CR,LF,0
msg_too_many_failure:		dc.b	'���s���������܂��B��قǂ܂�����蒼�����������B',CR,LF,0
msg_too_many_tries:		dc.b	'��蒼�����������܂��B��قǂ܂�����蒼�����������B',CR,LF,0
.else
msg_bsd_too_short:		dc.b	'�����ƒ����p�X���[�h�����g�����������B',CR,LF,0
msg_bsd_mismatch:		dc.b	'���v���Ă��܂���B'
msg_password_unchanged:		dc.b	'�p�X���[�h�͕ύX����܂���ł����B',CR,LF,0
.endif

path_passwd:			dc.b	'/etc/passwd',0
path_ptmp:			dc.b	'/etc/ptmp',0
dot_000:			dc.b	'.000'
str_nul:			dc.b	0
itoa64:				dc.b	'./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
*****************************************************************
.bss
.even
bsstop:
.offset 0
sysroot:		ds.l	1
name:			ds.l	1
ptmp_fd:		ds.l	1
passwd_fd:		ds.w	1
irandom_struct:		ds.b	IRANDOM_STRUCT_HEADER_SIZE+(2*RANDOM_POOLSIZE)
pwd_buf:		ds.b	PW_SIZE
pwd_line:		ds.b	PW_LINESIZE
crypt_buf:		ds.b	16
ptmp:			ds.b	MAXPATH+1
passwd:			ds.b	MAXPATH+1
opasswd:		ds.b	MAXPATH+1
namebuf:		ds.b	MAXLOGNAME+1
old_password:		ds.b	MAXPASSWD+1
new_password:		ds.b	MAXPASSWD+1
password_buf:		ds.b	MAXPASSWD+1
salt:			ds.b	3
failures_count:		ds.b	1
tries_count:		ds.b	1
remove_ptmp:		ds.b	1
.even
			ds.b	STACKSIZE
.even
stack_bottom:

args_buffer:
*****************************************************************
.end start
