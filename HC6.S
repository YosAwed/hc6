*
*	hc6 6git encoder decoder for msc
*	by tam(asc10041) 860620
*	modified by y.tokugawa (asc11161) 860623
*	version 1.10 by tom (asc10041) 860623
*	for basic by calf (asc14245)
*	  x-basic by BIG-X (pcs12107) 870707
*           As68k by ON (pcs26419) 870906
*
*	encode:
*		hc6 filename [/Lnumber]
*	decode:
*		hc6 file.hc6
*	help:
*		hc6
*

****** doscall equ ************
_exit:		equ	$FF00
_print:		equ	$FF09
_namests:	equ	$FF29
_creat:		equ	$FF3C
_open:		equ	$FF3D
_close:		equ	$FF3E
_read:		equ	$FF3F
_write:		equ	$FF40
_delete:	equ	$FF41
_setblock:	equ	$FF4A

********* defult **************
defpakl:	equ	56
offset:		equ	$30

******* work (A5) equ *********
fi		equ	0
fo		equ	2


*************************************************
*		 スタート			*
*************************************************
* read_buffer	: A0
* write_buff	: A1
* rfilename	: A3
* ofilename	: A4
* workbuffer	: A5
***************************

hc6:		bsr	m_opening	;オープニングメセージ
		tst.b	(A2)+
		beq	m_help		;コマンド列なし（ＨＥＬＰ）

****** データエリアの確保 *******

		movea.l	A1,A5		;A5: ワークバッファ
		adda.l	#$10,A0
		suba.l	A0,A1
		adda.l	#128+128+50+50+10,A1	;データサイズ 
		movem.l	A0-A1,-(SP)
		dc.w	_setblock
		addq.l	#8,SP
		tst.l	D0
		bmi	e_memory

		lea	10(A5),A0	;A0: リードバッファ
		lea	128(A0),A1	;A1: ライトバッファ
		lea	128(A1),A3	;A3: 入力ファイル名バッファ
		lea	50(A3),A4	;A4: 出力ファイル名バッファ

*********************************
		bsr	set_fname	;フィイル名のセット＆選択

		bne	encode		;ＨＣ６エンコードへ
		bra	decode		;ＨＣ６デコードへ

*********************************
*   ファイルネームをセット      *
*********************************
set_fname:	move.l	A3,-(SP)
set_ifname:	move.b	(A2)+,D0	;パス￥ファイル名の取り出し
		beq	set_if0
		cmpi.b	#' ',D0
		beq	set_if0				
		move.b	D0,(A3)+
		bra	set_ifname
set_if0:	clr.b	0(A3)
		move.l	(SP)+,A3

		move.l	A0,-(SP)	;ファイルをバッファに展開
		move.l	A3,-(SP)
		dc.w	_namests
		addq.l	#8,SP
		tst.l	D0
		bmi	e_help		;ファイル名が異常

		cmpi.b	#'H',75(A0)	;拡張子を調べる
		beq	tst_C
		cmpi.b	#'h',75(A0)
		bne	set_HC6
tst_C:		cmpi.b	#'C',76(A0)
		beq	tst_6
		cmpi.b	#'c',76(A0)
		bne	set_HC6
tst_6:		cmpi.b	#'6',77(A0)
		bne	set_HC6
		rts			;デコード（Ｚ＝１）


set_HC6:	movem.l	A0-A1/A4,-(SP)	;ここからエンコードね
		lea.l	67(A0),A0	;出力ファイル名のセット
		move.b	#'#',(A1)+	:＃
		move.w	#7,D0
set_HC6lp1:	move.b	(A0),(A4)+	;出力ファイル名 (1..8)
		move.b	(A0)+,(A1)+	;＃ファイル名   (1..8)
		cmpi.b	#' ',-1(A0)
		dbeq	D0,set_HC6lp1
		beq	set_HC6_O

		addq.l	#3,A0
		move.w	#10,D0
set_HC6lp3:	move.b	(A0),(A4)+	;出力ファイル名 (9..18)
		move.b	(A0)+,(A1)+	;＃ファイル名　 (9..18)
		dbeq	D0,set_HC6lp3

set_HC6_O:	move.b	#'.',-1(A4)	;拡張子は　．ＨＣ６
		move.b	#'H',(A4)+
		move.b	#'C',(A4)+
		move.b	#'6',(A4)+
		clr.b	0(A4)

		movea.l	0(SP),A0	;＃拡張子
		subq.l	#1,A1
		cmp.b	#' ',75(A0)
		beq	set_HC6_00	;拡張子なし
		move.b	#'.',(A1)+
		move.b	75(A0),(A1)+
		move.b	76(A0),(A1)+
		move.b	77(A0),(A1)+
set_HC6_00:	move.b	#' ',0(A1)
		movem.l	(SP)+,A0-A1/A4
*
*	ひきつづき　パケットの長さを調べる
*

		move.l	#defpakl,D1	;デフォルトの長さ
		subq.l	#1,A2
skipspc:	move.b	(A2)+,D0
		cmpi.b	#' ',D0
		beq	skipspc
		tst.b	D0
		beq	switch_ret	;スイッチなし
*
tst_switch:	cmp.b	#'/',D0		;スイッチの書式を調べる
		bne	e_help		;ｅｒｒｏｒ
		move.b	(A2)+,D0
		cmp.b	#'l',D0
		beq	set_len
		cmp.b	#'L',D0
		bne	e_help		;ｅｒｒｏｒ

set_len:	clr.w	D1		;長さを読む
		clr.w	D0
set_len10:	tst.b	0(A2)
		beq	set_len_exit
		lsl.w	#1,D1		;D1=D1*10
		move.w	D1,D2
		lsl.w	#2,D1
		add.w	D2,D1

		move.b	(A2)+,D0
		subi.b	#'0',D0
		blo	e_help
		cmpi.b	#9,D0
		bhi	e_help

		add.w	D0,D1
		bra	set_len10

set_len_exit:	tst.w	D1
		beq	e_help
		cmpi.w	#64,D1
		bhs	e_help
switch_ret:	move.w	D1,D5		;長さを変更
		rts			;エンコード（Ｚ＝０）


*********************************************************
*							*
*		ＨＣ６　ＥＮＣＯＤＥ			*
*							*
*********************************************************
* fr		:D3
* dl		:D4
* packetl	:D5
* write_size	:D6
*************************

encode:		bsr	f_openR		;Ｒ／Ｗファイルをオープン
		bsr	f_openW
		bsr	m_encode

		moveq.l	#0,D3

		move.l	A1,-(SP)	;Ｖ１１０ヘッダー部
		moveq.l	#-1,D6
encode_l1:	addq.l	#1,D6
		cmpi.b	#' ',(A1)+
		bne	encode_l1
		move.l	(SP)+,A1
		bsr	f_writeln
*
*	ループスタート
*
encode_lp:	moveq.l	#1,D6		;ライトサイズ初期値
		bsr	f_read		;１パケット読み込み
		tst.w	D4
		beq	encode_dl	;終了
		
		clr.b	D0		;チェックサム
		movem.l	D4/A0,-(SP)
sum_lp		add.b	(A0)+,D0
		sub.w	#1,D4
		bne	sum_lp
		move.b	D0,0(A0)
		movem.l	(SP)+,D4/A0
		addq.l	#1,D4

		bsr	encd

		move.b	#offset,D0
		add.b	D3,D0
		move.b	D0,1(A1)
		addq.l	#1,D3
		cmpi.b	#64,D3
		bne	encode_dl
		moveq.l	#0,D3

encode_dl:	move.b	#offset,D0
		add.b	D4,D0
		move.b	D0,0(A1)

		bsr	f_writeln	;一行書き込み

		tst.b	D4
		bne	encode_lp

**************** さようなら *****************

hc6_exit:	bsr	f_closeRW	;ファイルを閉じて
		bsr	m_complete
		dc.w	_exit		;さようなら
		
*************************************************
*		エンコード本体			*
*************************************************
encd:		movem.l	D4/A0-A1,-(SP)		
		addq.l	#2,A1

encd_lp:	move.b	(A0)+,D0	; |765432|10xxxx|
		move.b	D0,D1
		lsr.b	#2,D0
		addi.b	#offset,D0
		move.b	d0,(A1)+
		lsl.b	#4,D1
		andi	#$30,D1
		subq.w	#1,D4
		beq	encd_exit1

		move.b	(A0)+,D0	; |xx7654|3210xx|
		move.b	D0,D2
		lsr.b	#4,D0
		add.b	D1,D0
		addi.b	#offset,D0
		move.b	D0,(A1)+
		lsl.b	#2,D2
		andi.b	#$3C,D2
		subq.w	#1,D4
		beq	encd_exit2

		move.b	(A0)+,D0	; |xxxx76|543210|
		move.b	D0,D1
		lsr.b	#6,D0
		add.b	D2,D0
		addi.b	#offset,D0
		move.b	D0,(A1)+
		andi.b	#$3F,D1
		addi.b	#offset,D1
		move.b	D1,(A1)+
		subq.w	#1,D4
		bne	encd_lp
		bra	encd_exit3

encd_exit1:	move.b	D1,D2		;最後の処理
encd_exit2:	addi.b	#offset,D2
		move.b	D2,(A1)+
encd_exit3:	move.l	A1,D6		;サイズをセット
		sub.l	8(SP),D6
		movem.l	(SP)+,D4/A0-A1
		rts

*********************************************************
*							*
*		ＨＣ６　ＤＥＣＯＤＥ			*
*							*
*********************************************************
* fr		:D4
* lineno	;D5
* dl		;D6
* enc		;D7
*********************************

decode:		bsr	f_openR
		bsr	f_reads

		movem.l	A0/A4,-(SP)
		moveq.l	#1,D7		;D7: v100
		cmpi.b	#34,(A0)+
		beq	decode2		;Ｖ１００出力ファイル名あり
decode1		moveq.l	#2,D7		;D7: V110
		cmpi.b	#'#',-1(A0)
		beq	decode2		;Ｖ１１０出力ファイル名あり

		lea	def_out(PC),A0	;ファイル名をＨＣ６．ＯＵＴにする
decode10	move.b	(A0)+,(A4)+
		bne	decode10
		movem.l	(SP)+,A0/A4
		bra	decode3

decode2		move.b	(A0)+,(A4)+	;出力ファイル名をセット
		cmpi.b	#13,-1(A4)
		bne	decode2
		move.b	#0,-(A4)
		movem.l	(SP)+,A0/A4
		bsr	f_reads

decode3		bsr	f_openW
		bsr	m_decode
		move.l	#offset,D4
		moveq.l	#1,D5
		moveq.l	#0,D6
*
*	ループスタート
*
decode_lp:	move.b	0(A0),D6
		subi.b	#offset,D6	;ｄｌをセット
		beq	hc6_exit	;終了
		bcs	e_frame		;< 0  error
		cmpi.b	#$40,D6		;> 64 error
		bhi	e_frame

		bsr	decd		;デコード

		cmpi.b	#1,D7		; v100?
		beq	decode4

		cmp.b	1(A0),D4	;ｆｒのテスト
		bne	e_frame		;ｆｒａｍｅ エラー

decode4:	addq.b	#1,D4
		cmpi.b	#offset+$40,D4
		bne	decode5
		move.b	#offset,D4

decode5:	subq.l	#1,D6
		clr.w	D1		;チェックサム
		move.w	D6,D0
		subq.w	#1,D0
decode5_lp:	add.b	0(A1,D0.w),D1
		dbra	D0,decode5_lp
		cmp.b	0(A1,D6.w),D1
		bne	e_checksum	;チェックサム　エラー	

		bsr	f_write
		addq.w	#1,D5
		bsr	f_reads
		bra	decode_lp

*****************************************
*	ＤＥＣＯＤＥ　本体		*
*****************************************
decd:		movem.l	D6/A0-A1,-(SP)
		lea.l	0(A0,D7.w),A0

decd_lp:	move.b	(A0)+,D1		;|765432|10xxx|
		subi.b	#offset,D1
		move.b	(A0)+,D0
		subi.b	#offset,D0
		move.b	D0,D2
		lsl.b	#2,D1
		lsr.b	#4,D0
		and.b	#$03,D0
		add.b	D1,D0
		move.b	D0,(A1)+
		subq.b	#1,D6
		beq	decd_exit

		move.b	(A0)+,D1		;|xx7654|3210xx|
		subi.b	#offset,D1
		move.b	D1,D0
		lsr.b	#2,D0
		andi.b	#$0F,D0
		lsl.b	#4,D2
		add.b	D2,D0
		move.b	D0,(A1)+
		subq.b	#1,D6
		beq	decd_exit

		move.b	(A0)+,D0		;|xxxx76|543210|
		subi.b	#offset,D0
		lsl.b	#6,D1
		andi.b	#$C0,D1
		add.b	D1,D0
		move.b	D0,(A1)+
		subq.b	#1,D6
		bne	decd_lp

decd_exit:	movem.l	(SP)+,D6/A0-A1
		rts

************************ ファイル処理 ****************************

*********************************
*	open read file		*
*********************************
f_openR:	move.w	#0,-(SP)
		move.l	A3,-(SP)
		dc.w	_open
		addq.l	#6,SP
		tst.l	D0
		bmi	e_openR
		move.w	D0,fi(A5)
		rts

*********************************
*	open write file		*
*********************************
f_openW:	move.w	#$20,-(SP)	;通常のファイル
		move.l	A4,-(SP)
		dc.w	_creat		;ファイル　クリエート
		addq.l	#6,SP
		tst.l	D0
		bmi	e_openW
		move.w	D0,fo(A5)
		rts

*********************************
*	   close file		*
*********************************
f_closeRW:	move.w	fo(A5),-(SP)
		dc.w	_close
		addq.l	#2,SP
f_closeR:	move.w	fi(A5),-(SP)
		dc.w	_close
		addq.l	#2,SP
		rts

*********************************
*       file write		*
*********************************
* buffer	:A1
* size		:D6
* fileNo	:fo(A5)
*********************************
f_writeln:	bsr	f_write
		move.l	#2,-(SP)
		pea	msg_crlf
		bra	f_write0

f_write:	move.l	D6,-(SP)
		move.l	A1,-(SP)
f_write0:	move.w	fo(A5),-(SP)
		dc.w	_write
		lea	10(SP),SP
		tst.l	D0
		bmi	e_write
		rts

*********************************
*	file read		*
*********************************
* buffer	:A0
* size		:D5
* fileNo	:fi(A5)
*
*>read size	:D4
*********************************
f_read:		clr.b	0(A0)
		bsr	f_read1
		move.l	D0,D4
		rts

f_read1:	move.l	D5,-(SP)
		move.l	A0,-(SP)
		move.w	fi(A5),-(SP)
		dc.w	_read
		lea	10(SP),SP
		tst.l	D0
		bmi	e_read
		rts
********************************

f_reads:	movem.l	D1/D5/A0,-(SP)
		move.w	#88,D1
		clr.b	0(A0)
		moveq.l	#1,D5
f_reads_lp:	bsr	f_read1
		beq	f_reads_exit
		cmpi.b	#10,(A0)+
		dbeq	D1,f_reads_lp
		bne	e_frame
f_reads_exit:	movem.l	(SP)+,D1/D5/A0
		rts	

*********************************
*	delete write file	*
*********************************
f_delete:	move.l	A4,-(SP)
		dc.w	_delete		;ＤＥＬＥＴＥ
		addq.l	#4,SP
		rts

************************ エラー 処理 **************************

*********************************
*	書式のエラー		*
*********************************
e_help:		pea	msg_help
		dc.w	_print
		dc.w	_exit

*********************************
*	setblock error		*
*********************************
e_memory:	pea	msg_e_memory
		dc.w	_print
		dc.w	_exit

*********************************
*	open error		*
*********************************
e_openW:	bsr	f_closeR
		move.l	A4,-(SP)
		bra	e_open

e_openR:	move.l	A3,-(SP)
e_open:		dc.w	_print
		pea	msg_e_open
		dc.w	_print
		dc.w	_exit

*********************************
*	frame error		*
*********************************
e_frame:	move.l	A3,-(SP)
		dc.w	_print
		pea	msg_e_frame
		bra	e_lineno

*********************************
*	checksum error		*
*********************************
e_checksum:	move.l	A3,-(SP)
		dc.w	_print
		pea	msg_e_sum
e_lineno:	dc.w	_print
		bsr	m_lnum		;ラインＮｏを出力
		move.l	A0,-(SP)
		dc.w	_print
		bsr	m_crlf
		bra	e_exit

******* １０進文字列変換  *******

m_lnum:		movem.l	A0-A1,-(SP)
		moveq	#4,D1		;bin to adic
		lea	exp_tbl(PC),A1
adec_lp0:	clr.b	D2
		move.w	(A1)+,D3
adec_lp1:	or	D3,D3
		sub.w	D3,D5
		bcs	adec2
		addq.b	#1,D2
		bra	adec_lp1
adec2:		add.w	D3,D5
		add.b	#'0',D2
		move.b	D2,(A0)+
		dbra	D1,adec_lp0

		clr.b	0(A0)
		movem.l	(SP)+,A0-A1
		rts

*********************************
*	read error		*
*********************************
e_read:		move.l	A3,-(SP)
		dc.w	_print
		pea	msg_e_read
		dc.w	_print
		bra	e_exit

*********************************
*	write error		*
*********************************
e_write:	move.l	A4,-(SP)
		dc.w	_print
		pea	msg_e_write
		dc.w	_print

*********************
e_exit:		bsr	f_closeRW	;ファイルクローズ
		bsr	f_delete	;出力ファイルの削除
		dc.w	_exit

*********************** メッセージ **************************

*********************************
*	massage r/w file	*
*********************************
m_encode:	pea	msg_encode
		bra	m_file

m_decode:	pea	msg_decode

m_file:		dc.w	_print
		move.l	A3,0(SP)
		dc.w	_print
		pea	msg_to
		dc.w	_print
		move.l	A4,0(SP)
		dc.w	_print
		addq.l	#8,SP
		bsr	m_crlf
		rts

*********************************
*	opening massage		*
*********************************
m_opening:	pea	msg_opening
		bra	print

*********************************
*	complete massage	*
*********************************
m_complete:	pea	msg_complete
		bra	print

*********************************
*	help massage & exit	*
*********************************
m_help:		pea	msg_help
		dc.w	_print

		dc.w	_exit		;exit

*********************************
*	print cr/lf		*
*********************************
m_crlf:		pea	msg_crlf

print:		dc.w	_print
		addq.l	#4,SP
		rts

************************ データ　エリア *********************
		.even
exp_tbl		dc.w	10000
		dc.w	1000
		dc.w	100
		dc.w	10
		dc.w	1

def_out		dc.b	'hc6.out',0
msg_opening	dc.b	'hc6: 6bit file comberter v1.10x copyright 1987 Pekin soft',13,10,0
msg_help	dc.b	'encode:',13,10
		dc.b	9,'hc6 failename [/l<1-63>]',13,10
		dc.b	'decode:',13,10
		dc.b	9,'hc6 file.hc6'
msg_crlf	dc.b	13,10,0
msg_encode:	dc.b	'encode: ',0
msg_decode:	dc.b	'decode: ',0
msg_to		dc.b	' ---> ',0
msg_complete	dc.b	'complete!',13,10,0

msg_e_memory	dc.b	'memory full error',13,10,0
msg_e_open	dc.b	': file open error',13,10,0
msg_e_write	dc.b	': file write error',13,10,0
msg_e_read	dc.b	': file read error',13,10,0
msg_e_frame	dc.b	': frame error in line',0
msg_e_sum	dc.b	': checksum error in line',0
		.even
		.end	hc6
