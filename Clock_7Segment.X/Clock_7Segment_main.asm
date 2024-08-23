
; PIC16F628A Configuration Bit Settings

; Assembly source line config statements

#include "p16f628a.inc"

; CONFIG
; __config 0x3F50
 __CONFIG _FOSC_INTOSCIO & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

 #define    TMR_INI	d'61'
 #define    CNT1MS	d'21'

    ;レジスタ定義
    CBLOCK	0x20
	w_tmp	    ;割り込みハンドラ用
	status_tmp  ;割り込みハンドラ用
	
	sec	;秒
	min	;分
	hour	;時間
	sec_swap    ;16の桁用
	min_swap    
	hour_swap
        digit	;表示桁（0(時間2桁目)～6(秒1桁)）
	count	;割り込み回数カウンター
	
	
	CNT1	;ダイナミック制御表示時間カウント用
	CNT2
    
    ENDC

    
    ORG	    0x00
    GOTO    setup
    
    ORG	    0x04
    GOTO    ISR
    
setup:
    BCF	    STATUS,RP0
    BCF	    STATUS,RP1
    
    ;CLRF    INTCON	;とりあえず割り込みダメ
    MOVLW   B'10100000'
    MOVWF   INTCON
    
    MOVLW   0x07
    MOVWF   CMCON	;コンパレータ無効（すべてデジタル）
    
    
    
    BSF	    STATUS,RP0	    ;バンク1に
    MOVLW   B'00000000'
    MOVWF   TRISA
    MOVWF   TRISB	    ;PORTA,Bともにすべて出力
    
    CLRF    PORTA
    CLRF    PORTB	    ;ポートをクリア
    
    
    BSF	    PCON,OSCF	    ;オシレーター4MHz
    
    BCF	    STATUS,RP0	    ;バンク0に
    
    MOVLW   B'10000111'	    ;プリスケーラ1/256
    OPTION
    
    CLRF    digit
    CLRF    sec
    CLRF    min
    CLRF    hour
    
    
main:
    MOVLW   TMR_INI
    MOVWF   TMR0	    ;タイマー0初期値	256-61=195
    MOVLW   CNT1MS
    MOVWF   count	    ;割り込み繰り返し回数初期値
    MOVLW   B'10100000'
    MOVWF   INTCON	    ;タイマー0のオバーフロー割り込み許可
    
main_loop:
    
    
    
    CALL    dynamic_con
    
    GOTO    main_loop

;ダイナミック制御
dynamic_con:
    MOVFW   digit	;何桁目かをwに
    CALL    a_pattern	;パターンを持ってくる
    MOVWF   PORTA	;PORTA出力
    
    
    MOVFW   digit	    ;各桁の処理に飛ぶ
    ANDLW   b'00000111'	    ;マスクする
    ADDWF   PCL,f
    GOTO    get_hour_16
    GOTO    get_hour
    GOTO    get_min_16
    GOTO    get_min
    GOTO    get_sec_16
    GOTO    get_sec
    
get_hour:
    MOVFW   hour	;時間の1桁目をとってくる
    GOTO    set_data
    
get_min:
    MOVFW   min		;分の1桁目をとってくる
    GOTO    set_data
    
get_sec:
    MOVFW   sec		;秒の1桁目をとってくる
    GOTO    set_data
    
    ;ここから16の桁の処理
get_hour_16:   
    SWAPF   hour,w	;時間の16桁目をとってくる
    GOTO    set_data
    
get_min_16:
    SWAPF   min,w	;分の16桁目をとってくる
    GOTO    set_data

get_sec_16:
    SWAPF   sec,w	;秒の16桁目をとってくる
    
set_data:
    CALL    segment_data    ;wの文字のデータをとってくる
    MOVWF   PORTB
    
    
    CALL    DLY_50
    
inc_digit:
    
    INCF    digit,f	;桁数をインクリメントして
    MOVLW   D'6'
    SUBWF   digit,w	;6と比較して
    BTFSS   STATUS,Z	;6だったらスキップ
    GOTO    dynamic_con
    
    CLRF    digit	;桁数を0に戻す
    RETURN

;PORTAパターン
a_pattern:
    ANDLW   b'00000111'	    ;マスクする
    ADDWF   PCL,f
    RETLW   b'11111110'	    ;RA0
    RETLW   b'11111101'	    ;RA1
    RETLW   b'11111011'	    ;RA2
    RETLW   b'11110111'	    ;RA3
    RETLW   b'11101111'	    ;RA4
    RETLW   b'10111111'	    ;RA6
    RETURN
      
;7セグデータ
segment_data:
    ANDLW   b'00001111'	    ;マスクする
    ADDWF   PCL,f
    RETLW   b'11000000'	    ;0
    RETLW   b'11111001'	    ;1
    RETLW   b'10100100'	    ;2
    RETLW   b'10110000'	    ;3
    RETLW   b'10011001'	    ;4
    RETLW   b'10010010'	    ;5
    RETLW   b'10000010'	    ;6
    RETLW   b'11111000'	    ;7
    RETLW   b'10000000'	    ;8
    RETLW   b'10010000'	    ;9
    RETLW   b'10001000'	    ;A
    RETLW   b'10000011'	    ;B
    RETLW   b'10100111'	    ;C
    RETLW   b'10100001'	    ;D
    RETLW   b'10000110'	    ;E
    RETLW   b'10001110'	    ;F
    RETURN
    
DLY_50:
    
    MOVLW   d'1'   ;1ms
    MOVWF   CNT1
    
DLP1:
    MOVLW   d'200'  ;1ms
    MOVWF   CNT2
    
DLP2:
    NOP
    NOP
    DECFSZ  CNT2,f
    GOTO    DLP2
    DECFSZ  CNT1,f
    GOTO    DLP1
    RETURN

;------------------------------------------------------------
;割り込み処理
ISR:
    MOVWF   w_tmp	    ;退避
    SWAPF   STATUS,w
    MOVWF   status_tmp
    DECF    count,f	    ;割り込み回数カウントデクリメント
    BTFSS   STATUS,Z	    ;カウントが0になったか？
    GOTO    set_timer	    ;0以外はTMR0設定へ
    CALL    countup	    ;カウントアップ処理（繰り上がり含む
    MOVLW   CNT1MS	    ;割り込み回数再設定
    MOVWF   count
    
    
set_timer:
    MOVLW   d'1'
    SUBWF   count,w	;
    BTFSS   STATUS,Z	;countが1ならスキップ
    GOTO    normal
    ;MOVLW   d'250'	;256-250=6  1536us計測
    MOVLW   d'200'	;256-185=71  1536us計測
    GOTO    set_point
    
normal:
    MOVLW   TMR_INI	    ;TMR0再設定
    
set_point:
    MOVWF   TMR0
    
    MOVLW   B'10100000'	    ;タイマー0のオバーフロー割り込み許可
    MOVWF   INTCON	    ;T0IFビットクリア
    
    SWAPF   status_tmp,w    ;復帰
    MOVWF   STATUS
    SWAPF   w_tmp,f
    SWAPF   w_tmp,w
    RETFIE  
    
    
    
    
;1秒カウントアップ（繰り上がりを含む
countup:
    INCF    sec,f   ;インクリメント
    MOVLW   d'60'
    SUBWF   sec,w   ;60引いてみて
    BTFSS   STATUS,Z	;0ならスキップ
    RETURN
    
    ;分の繰り上がり
    CLRF    sec	    ;秒を0に
    INCF    min,f   ;分をインクリメント
    MOVLW   d'60'
    SUBWF   min,w   ;60引いてみて
    BTFSS   STATUS,Z	;0ならスキップ
    RETURN
    
    ;時間の繰り上がり
    CLRF    min	    ;分を0に
    INCF    hour,f  ;時間をインクリメント
    MOVLW   d'24'
    SUBWF   hour,w  ;24引いてみて
    BTFSS   STATUS,Z	;0ならスキップ
    RETURN
    
    ;24時間経ったら全部クリア
    CLRF    hour
    CLRF    min
    CLRF    sec
    
    RETURN
    
 
 
END
 
 